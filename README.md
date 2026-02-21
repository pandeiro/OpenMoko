![OpenMoko Screenshot](screenshot.png)

# OpenMoko (Mobile Coding) v0.3

> Code, debug, and deploy from anywhere using AI agents.

OpenMoko is a self-hosted, mobile-first development environment that lets you go from idea → agent → production entirely from your phone.

It bundles [OpenCode](https://opencode.ai/) with a custom multi-service architecture for repository management, voice entry, and CI/CD awareness.

## New in v0.3
- **Init PWA**: A dedicated mobile entry point with project picking and voice-to-prompt reformulation.
- **Repo Management UI**: No more `repos.txt`. Manage your GitHub projects directly from the mobile app.
- **CI/CD Awareness**: Real-time push notifications for build passes/failures.
- **Failure Resume**: Failed a build? See the logs on your phone and send a fix to the agent with one tap.
- **Universal Toolchain Support**: Powered by [`mise`](https://mise.jdx.dev/), your agent can instantly install any language or tool (Node, Python, Rust, Go, etc.) on-demand—no image rebuilds, no host OS dependencies.

## Architecture
- **`opencode`**: The core development environment.
- **`openmoko-init`**: Static PWA frontend (Vite-based).
- **`openmoko-events`**: Node.js backend for API, GitHub integration, and push notifications.
- **`openmoko-gateway`**: Reverse proxy routing all traffic through port 7777.

## Quick Setup

### Prerequisites
- **Docker** and **Docker Compose** installed on your VPS or local machine
- **Git** configured with SSH keys for private repo access

### Required Authentication
| Credential | Purpose |
|------------|---------|
| `SSH Key` | Clone private repositories from GitHub |
| `GITHUB_PAT` | List and search your GitHub repos in the UI |

### Optional Authentication
| Credential | Purpose |
|------------|---------|
| `GROQ_API_KEY` | Primary AI for voice prompt reformulation (fast, high-quality) |
| `GEMINI_API_KEY` | Fallback AI for voice reformulation |
| `WHISPER_API_KEY` | Improved voice-to-text accuracy (OpenAI) |
| Web Push (VAPID) | CI/CD failure push notifications to your phone |

### Deploy

```bash
# 1. Clone and configure
cp .env.example .env
nano .env  # Set required: GITHUB_PAT, SSH key. Optional: AI keys, VAPID

# 2. Add SSH key (required for private repo cloning)
cp ~/.ssh/id_rsa ./ssh/ && chmod 600 ./ssh/id_rsa

# 3. Build and Run
docker compose up --build -d

# 4. Access
# Mobile PWA (recommended): http://your-vps-ip:7777/init/
# Full OpenCode editor: http://your-vps-ip:7777/
```

> **Note:** For production VPS deployments with HTTPS and domain setup, see [Deployment](doc/deployment.md).

## Configuration

### Environment Variables (.env)

Detailed in `.env.example`. Key groups:
- **Git Identity**: `GIT_USER_NAME`, `GIT_USER_EMAIL`
- **Security**: `OPENCODE_SERVER_PASSWORD`
- **GitHub**: `GITHUB_PAT` (for repo listing/cloning), `GITHUB_WEBHOOK_SECRET`
- **Web Push**: Generate VAPID keys using `npx web-push generate-vapid-keys`
  - `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_CONTACT`
- **AI Inference**:
  - `WHISPER_API_KEY` (OpenAI - optional for improved voice)
  - `GROQ_API_KEY` (Llama 3.3 70B - primary reformulation)
  - `GEMINI_API_KEY` (Gemini Flash - fallback reformulation)

### GitHub Webhook Setup

Total CI/CD awareness requires a webhook on your repositories:
1. **Payload URL**: `https://your-openmoko-domain.com/webhooks/github`
2. **Content type**: `application/json`
3. **Secret**: Matches your `GITHUB_WEBHOOK_SECRET`
4. **Events**: `push`, `workflow_run`, `pull_request`

## Usage

### Managing Repositories
Open the Init PWA and tap the gear icon ⚙️. Search for your GitHub repos and tap "Enable". OpenMoko will handle cloning in the background.

### Starting a Task
1. Select a repo from the picker.
2. Tap the Mic 🎙️ and speak your task.
3. Review the AI-reformulated prompt.
4. Tap "Branch & Start" to trigger the agent.

### Resuming Failures
If a CI check fails, you'll receive an OS-level push notification. Tap it to see the failing logs and send a fix instruction back to the agent.

## Persistence
- `/workspace`: Cloned projects.
- `events_data` (volume): Repo state, sessions, and failure records.
- `mise_data` (volume): Persisted language/toolchain installations across container restarts.

## License
Provided as-is for personal and commercial use.
