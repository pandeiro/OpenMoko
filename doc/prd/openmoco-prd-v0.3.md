# OpenMoco PRD — v0.3 Draft

**Scope:** Two-week solo sprint  
**Features:** Init (voice entry) · CI/CD awareness + push notifications · Repo management  
**Out of scope:** Autonomous agent mode · PR creation · multi-provider CI · OpenCode fork

---

## Architecture

**Greenfield PWA wrapper, not an OpenCode fork.** Init is a separate PWA served at `/init`. OpenCode runs unchanged at `/`. Handoff uses the `@opencode-ai/sdk` — no scraping, no forking.

**Internal nginx as network hub.** An nginx container inside docker-compose routes all internal traffic. The developer's existing reverse proxy points at one host port (`7777` by default). See Appendix C for the full nginx.conf.

**No repos.txt.** Replaced by a repo management UI backed by the GitHub API. The PAT required for CI/CD is the same one used to fetch and manage repos.

**Singleton active session.** OpenMoco tracks one active session at a time in `active_session.json` on the events_data volume. Starting a new task overwrites it. Sessions are abandoned on the OpenCode side (not explicitly deleted) — at personal use scale this is fine. The active session is cleared when its branch is detected as merged via GitHub webhook. This sidesteps all session lifecycle and workspace cleanup complexity.

**CI/CD notifications are Web Push.** No surface to inject toasts into OpenCode's UI without forking. Service worker registered by Init receives push events and delivers OS-level notifications visible even when backgrounded.

**Service worker from day one.** Start thin (push subscriptions, offline Init shell, notification click routing), grow later.

---

## Speech & Inference Stack

**Web Speech API always runs.** It provides live transcription display during recording, native silence detection via `speechend`/`onend` events (no manual AudioContext analysis needed), and the fallback transcript if Whisper is not configured. Browser-native, no cost, routes through Apple/Google servers depending on platform.

**Whisper enhances if configured.** If `WHISPER_API_KEY` is set, the audio blob is also POSTed to `/api/transcribe` which forwards to OpenAI Whisper. On return, Whisper's transcript replaces the Web Speech result before reformulation. Whisper is meaningfully better on technical vocabulary (variable names, library names, jargon). Cost ~$0.006/min, negligible at personal use volumes.

The UX is identical either way — the developer sees live text during recording regardless. Whisper just improves what gets handed to reformulation.

**Reformulation — Groq (free tier, default).** A single LLM call: raw transcript + project context → clean agent prompt. Groq with Llama 3.3 70B is fast, capable, and free to use from your own app. Gemini Flash (AI Studio free tier) is the configurable alternative. Branch slug generation happens in the same call — no extra round trip.

**Reformulation system prompt includes:**
- Raw transcript
- Active project: name, description, default branch, last pushed
- List of other enabled repos (so model can flag if it sounds like the wrong project)
- Instruction: *reformat into a clear, well-scoped agent prompt; preserve all technical specifics; output only the reformulated prompt and, if branching, a kebab-case branch slug — no commentary*

**New `.env` vars for inference:**
```
WHISPER_API_KEY=    # optional — OpenAI key, transcription only. Omit to use Web Speech API alone.
GROQ_API_KEY=       # reformulation default
GEMINI_API_KEY=     # reformulation alternative (optional; may already be set for OpenCode)
```

---

## Feature 0: Repo Management

Foundational to everything — project selection is required input to `session.create()`, and repo metadata feeds the reformulation call.

### First run experience

Init detects no enabled repos on first load and shows a welcome state: a prompt to connect GitHub and enable repos, or a "New project" path for starting from scratch (empty `/workspace` directory, no GitHub repo yet). Repo management is not a separate settings page — it's the first thing Init shows when there's nothing enabled.

On subsequent loads, a **gear icon** in the Init header opens the repo management view. Enabled repos appear in the project picker; everything else is invisible to the main flow.

### Repo management UI (`/init/repos`)

- List of user's GitHub repos fetched via PAT, cached locally, refresh button available
- Each repo: name, description, last pushed, enabled toggle
- Search/filter at the top
- On enable: clone triggered (see below), status shown inline ("Cloning..." → "Ready")
- On disable: confirm prompt, then removal from workspace

### Clone delegation

The events service cannot write to `/workspace` directly without getting read-write access to a volume that other services may expect to control. Instead, cloning is delegated to the opencode container via an internal API call — opencode already has git, SSH keys, mise, and the workspace mount. The events service POSTs to an internal endpoint (or runs a command via docker exec equivalent) and opencode performs the clone. This keeps filesystem authority with the container that owns it.

*This is the one piece of the architecture that needs a spike on day one — confirm the cleanest way to trigger a clone in the opencode container from the events service.*

### Data stored per repo (in events_data)

See Appendix D for full data model.

---

## Feature 1: Init

The mobile entry point for starting an agent task.

### Visual Design
- **Aesthetic**: Clean, modern look, mirroring OpenCode's interface design.
- **Theming**: Native CSS variables supporting Light and Dark modes. Defaults to matching the system (`prefers-color-scheme`).

### Happy path

1. Developer opens `openmoco.yourvps.com/init`
2. If no repos enabled → welcome/onboarding state. Otherwise: **project picker** — horizontally scrollable row of enabled repo chips, most recently active first. Tap to switch. Gear icon → repo management. (Note: Implemented as a direct project selection list in v0.3).
3. **Voice button** — tap to begin. Web Speech API starts immediately; flowing live transcription appears on screen as the developer speaks.
4. **Pause Detection & Grace Period:**
   - When the user pauses speaking, a visual **2.5s timer** begins running on screen.
   - If the timer hits 0 (2.5s elapsed), the system determines the user has stopped, and a **"Continue Talking" button** appears temporarily for 1 second.
   - If tapped within that 1 second, the user can continue talking and append more speech to the current transcript (the same recording session stays active).
   - If ignored, the recording definitively stops, defaulting to "send" the audio to the processing pipeline (total 3.5s elapsed since speech stopped).
   - A manual stop/send button is always visible to skip the wait.
5. If `WHISPER_API_KEY` configured: audio blob POSTs to `/api/transcribe`, Whisper result replaces Web Speech transcript. "Improving transcript..." shown briefly.
6. Transcript POSTs to `/api/reform` with project context. "Reformulating..." shown.
7. Cleaned prompt appears in editable text field. Re-record icon (↺) lets developer discard and start over.
8. **Two action buttons:**
   - **`Branch & Start →`** — primary, visually dominant. Default.
   - **`Start on main →`** — secondary, smaller. Requires deliberate tap.
9. **Notification toggle** — below the buttons, "Notify me when CI completes" on/off, default on. If on and push permission not yet granted, tapping either Start button triggers the permission prompt before proceeding.
10. On tap:
    - Events service calls `client.session.create({ projectPath: '/workspace/[repo]' })`
    - Calls `client.session.prompt(session.id, { text: formattedPrompt, mode: 'plan' })`
    - Prompt includes branch instruction if applicable: `git checkout -b [slug]` as first action
    - Stores session ID + repo + branch in `active_session.json`
    - Returns `{ sessionId, redirectUrl }` to client
    - Browser navigates to `openmoco.yourvps.com/#/session/[sessionId]`
    - OpenCode receives the session already live

### SDK usage

`@opencode-ai/sdk` is used server-side from the events service to avoid exposing OpenCode internals to the client. The events service is initialised with OpenCode's internal base URL (`http://opencode:8080`) and `OPENCODE_SERVER_PASSWORD`. One client endpoint wraps the two SDK calls:

```
POST /api/session/create
  body: { projectPath, prompt, branch?, slug? }
  returns: { sessionId, redirectUrl }
```

See Appendix B for SDK spike checklist.

### "New project" path

If the developer selects "New project" (no GitHub repo, starting from scratch):
- Init prompts for a project name
- Events service creates `/workspace/[name]`, runs `git init`
- Session created against that path
- No CI/CD webhook available until they add a remote — Init notes this inline

---

## Feature 2: CI/CD Awareness

After the agent pushes, the developer knows what happened without switching apps.

### Happy path

1. Agent pushes branch. GitHub fires `push` + `workflow_run` events to `/webhooks/github`.
2. Webhook receiver validates (HMAC-SHA256), matches against active session branch.
3. On workflow completion → Web Push notification dispatched.
4. **Pass:** `✓ fix/admin-route-auth-bypass passed — your-repo`
5. **Fail:** `✗ fix/admin-route-auth-bypass failed — Run tests — tap to send to agent`
6. Tapping a pass notification opens OpenCode at the active session.
7. Tapping a failure notification opens `/init/resume?failureId=[id]`. Init reads the stored failure record, calls `client.session.prompt()` on the active session with the pre-composed follow-up (failing step name + last ~50 lines of stderr/assertion output), and redirects to the session. Developer can add a note on the resume screen before sending, or just tap the send arrow.
8. On `pull_request` webhook event with `merged: true` matching the active session branch: `active_session.json` is cleared.

### Failure message assembly

Payload sent to agent = failing job name + failing step name + last 50 lines of that step's log (fetched via GitHub API using PAT). Sufficient for most test and compiler failures without overwhelming context. Stored as a failure record in events_data until the session is cleared.

### What this doesn't do (v1)

- No in-app CI panel — notifications are the entire CI UI surface
- No auto-forwarding to agent — resume screen requires a deliberate send tap
- No GitLab, CircleCI, Buildkite
- No PR creation

---

## openmoco-events Service

Node.js, ~350 lines:

| Endpoint | Purpose |
|---|---|
| `POST /webhooks/github` | Validate + handle `push`, `workflow_run`, `pull_request` events |
| `GET /events` | SSE (future in-page use) |
| `POST /api/subscribe` | Store Web Push subscription |
| `POST /api/transcribe` | Proxy audio blob → Whisper API (no-op passthrough if unconfigured) |
| `POST /api/reform` | Groq/Gemini call with transcript + context → `{ prompt, slug? }` |
| `POST /api/session/create` | OpenCode SDK: create session + send prompt → `{ sessionId, redirectUrl }` |
| `GET /api/repos` | GitHub API proxy merged with local enabled state |
| `POST /api/repos/:name/enable` | Trigger clone in opencode container, store state |
| `POST /api/repos/:name/disable` | Remove from workspace (confirmed), store state |

---

## docker-compose

```yaml
services:

  opencode:
    # unchanged from existing setup

  openmoco-nginx:
    image: nginx:alpine
    ports:
      - "7777:80"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - opencode
      - openmoco-init
      - openmoco-events

  openmoco-init:
    image: nginx:alpine
    volumes:
      - ./init/dist:/usr/share/nginx/html:ro
    expose: ['3000']

  openmoco-events:
    build: ./events
    env_file: .env
    expose: ['3001']
    volumes:
      - ./workspace:/workspace:rw    # rw needed for clone delegation
      - ./ssh:/root/.ssh:ro          # git over SSH
      - events_data:/data

volumes:
  mise_data:      # existing
  events_data:    # new
```

*Note: if clone delegation goes via the opencode container rather than directly, the events service workspace mount can revert to `:ro`. Decide after the day-one spike.*

---

## Full `.env`

```
# Git identity (existing)
GIT_USER_NAME=
GIT_USER_EMAIL=

# OpenCode (existing)
OPENCODE_SERVER_PASSWORD=

# GitHub
GITHUB_PAT=               # repo scope — repo listing, cloning, log fetching
GITHUB_WEBHOOK_SECRET=    # HMAC validation for inbound webhooks

# Web Push (VAPID) — generate once: npx web-push generate-vapid-keys
VAPID_PUBLIC_KEY=
VAPID_PRIVATE_KEY=
VAPID_CONTACT=mailto:you@example.com

# Inference
WHISPER_API_KEY=          # optional — omit to use Web Speech API transcript only
GROQ_API_KEY=             # reformulation (default)
GEMINI_API_KEY=           # reformulation alternative (optional)
```

---

## Out of Scope

- Autonomous / fire-and-forget agent mode
- In-app diff viewer or CI panel
- PR auto-creation
- GitLab, CircleCI, Buildkite
- Forking or modifying OpenCode's web UI
- Task templates *(fast-follow once Init ships)*
- Multi-user / team features
- Silence threshold configuration (hardcoded at 2.5s for v1)

---

## Open Questions

**Clone delegation mechanism:** Does the events service write directly to `/workspace` (simpler, requires rw mount), or does it trigger the opencode container to perform the clone (cleaner ownership, needs an IPC mechanism)? Spike on day one.

**OpenCode URL routing:** Confirm that `/#/session/[sessionId]` is the correct URL pattern for deep-linking to a session. Check OpenCode source or network traffic from the existing UI.

**`pull_request` webhook for session clearing:** Requires the `pull_request` event type to be added to the GitHub webhook configuration alongside `push` and `workflow_run`. Document in setup guide.

---

---

## Appendix A: Speech Pipeline State Machine

```
IDLE
  │
  └─[tap voice button]──────────────────────────────────────────►RECORDING
                                                                      │
                                                    Web Speech API running
                                                    Live transcript updating
                                                                      │
                                              ┌───────────────────────┤
                                              │                       │
                                       [speechend /            [manual stop]
                                        silence]                      │
                                              └───────────────────────┘
                                                                      │
                                                                      ▼
                                                              ┌──────────────┐
                                                              │ WHISPER_API  │
                                                              │ configured?  │
                                                              └──────┬───────┘
                                                                     │
                                              ┌──────────────────────┤
                                              │ NO                   │ YES
                                              ▼                      ▼
                                     use Web Speech          TRANSCRIBING
                                     transcript              (POST audio blob
                                              │               → /api/transcribe)
                                              │                      │
                                              │              [Whisper returns]
                                              │              replace transcript
                                              └──────────────────────┘
                                                                      │
                                                                      ▼
                                                              REFORMULATING
                                                         (POST transcript + context
                                                          → /api/reform)
                                                                      │
                                                              [model returns]
                                                                      │
                                                                      ▼
                                                               REVIEWING
                                                         (editable prompt field,
                                                          re-record icon,
                                                          branch/main buttons,
                                                          notification toggle)
                                                                      │
                                              ┌───────────────────────┤
                                              │                       │
                                    [re-record ↺]            [Branch & Start →]
                                              │               [Start on main →]
                                              ▼                       │
                                         RECORDING                    ▼
                                         (restart)            SUBMITTING
                                                         (POST /api/session/create
                                                          → SDK calls
                                                          → store active_session
                                                          → return redirectUrl)
                                                                      │
                                                                      ▼
                                                          navigate to OpenCode session
                                                                   DONE
```

**Error states** (from any async step):
- Transcription failure → show raw Web Speech transcript, allow proceed
- Reformulation failure → show raw transcript as editable prompt, allow proceed
- Session create failure → show error inline, retry button, do not navigate

---

## Appendix B: OpenCode SDK Spike Checklist

Confirm these on day one before writing any Init/events code that depends on them. Should take ~30 minutes.

- [ ] `@opencode-ai/sdk` installs and runs in Node.js (not browser-only)
- [ ] SDK client accepts a base URL and auth credential at initialisation — confirm the exact constructor signature
- [ ] `client.session.create()` — confirm what `projectPath` expects (absolute path? relative? must exist?)
- [ ] `client.session.prompt()` vs `promptAsync()` — which is appropriate for fire-and-check (we redirect immediately; we don't wait for the agent to finish)
- [ ] Session ID format and how it appears in OpenCode's URL routing — confirm `/#/session/[id]` or equivalent by checking network traffic from the existing web UI
- [ ] Whether an abandoned session (one we created but never explicitly deleted) causes any issues — check if OpenCode has session limits or cleanup behavior

---

## Appendix C: nginx.conf

```nginx
events {}

http {
  upstream opencode {
    server opencode:8080;
  }

  upstream openmoco_init {
    server openmoco-init:3000;
  }

  upstream openmoco_events {
    server openmoco-events:3001;
  }

  server {
    listen 80;

    # Init PWA
    location /init/ {
      proxy_pass http://openmoco_init/;
      proxy_set_header Host $host;
    }

    # Backend API (transcribe, reform, session, repos)
    location /api/ {
      proxy_pass http://openmoco_events/api/;
      proxy_set_header Host $host;
      # Increase timeout for audio upload + Whisper round trip
      proxy_read_timeout 30s;
      client_max_body_size 10m;
    }

    # SSE — disable buffering
    location /events {
      proxy_pass http://openmoco_events/events;
      proxy_set_header Host $host;
      proxy_set_header Connection '';
      proxy_http_version 1.1;
      proxy_buffering off;
      proxy_cache off;
      chunked_transfer_encoding on;
    }

    # GitHub inbound webhooks
    location /webhooks/ {
      proxy_pass http://openmoco_events/webhooks/;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
    }

    # OpenCode — catch-all
    location / {
      proxy_pass http://opencode/;
      proxy_set_header Host $host;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_http_version 1.1;
    }
  }
}
```

---

## Appendix D: Data Model (events_data volume)

All state is stored as JSON files on the `events_data` Docker volume at `/data/`. No database. Last-write-wins; concurrent writes are not a concern at single-user scale.

### `/data/active_session.json`

```json
{
  "sessionId": "abc123",
  "repo": "my-api",
  "projectPath": "/workspace/my-api",
  "branch": "fix/admin-route-auth-bypass",
  "createdAt": "2026-02-19T21:00:00Z",
  "notificationsEnabled": true
}
```

Overwritten on every new task start. Cleared (file deleted or set to `null`) when the branch is merged.

### `/data/repos.json`

```json
{
  "my-api": {
    "enabled": true,
    "cloneStatus": "ready",
    "githubMeta": {
      "description": "Main backend API",
      "defaultBranch": "main",
      "lastPushed": "2026-02-19T18:00:00Z",
      "private": true
    },
    "enabledAt": "2026-02-01T10:00:00Z"
  },
  "frontend": {
    "enabled": false,
    "cloneStatus": null,
    "githubMeta": { ... }
  }
}
```

### `/data/push_subscriptions.json`

```json
[
  {
    "endpoint": "https://fcm.googleapis.com/...",
    "keys": {
      "p256dh": "...",
      "auth": "..."
    },
    "subscribedAt": "2026-02-10T09:00:00Z"
  }
]
```

Array — one entry per device/browser that has granted push permission. Entries are never explicitly removed in v1 (stale subscriptions result in a 410 from the push service, at which point the server should remove them — handle this in the push dispatch logic).

### `/data/failures/[failureId].json`

```json
{
  "failureId": "f-20260219-001",
  "sessionId": "abc123",
  "repo": "my-api",
  "branch": "fix/admin-route-auth-bypass",
  "workflowName": "CI",
  "failingJob": "test",
  "failingStep": "Run tests",
  "logTail": "...last 50 lines of stderr...",
  "capturedAt": "2026-02-19T21:45:00Z",
  "consumed": false
}
```

Written when a workflow failure is received. Marked `consumed: true` when the developer sends it to the agent. Failures older than 48 hours can be pruned on startup.
