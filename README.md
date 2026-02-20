![OpenMoco Screenshot](screenshot.png)

# OpenMoco (Mobile Coding) v0.3

> Code, debug, and deploy from anywhere using AI agents.

OpenMoco is a self-hosted, mobile-first development environment that lets you go from idea → agent → production entirely from your phone.

It bundles [OpenCode](https://opencode.ai/) with a custom multi-service architecture for repository management, voice entry, and CI/CD awareness.

## New in v0.3
- **Init PWA**: A dedicated mobile entry point with project picking and voice-to-prompt reformulation.
- **Repo Management UI**: No more `repos.txt`. Manage your GitHub projects directly from the mobile app.
- **CI/CD Awareness**: Real-time push notifications for build passes/failures.
- **Failure Resume**: Failed a build? See the logs on your phone and send a fix to the agent with one tap.

## Architecture
- **`opencode`**: The core development environment.
- **`openmoco-init`**: Static PWA frontend (Vite-based).
- **`openmoco-events`**: Node.js backend for API, GitHub integration, and push notifications.
- **`openmoco-nginx`**: Reverse proxy routing all traffic through port 7777.

## Quick Setup

```bash
# 1. Clone and configure
cp .env.example .env
# Edit .env and follow the Configuration section below
nano .env

# 2. Add SSH keys (required for private repo cloning)
cp ~/.ssh/id_rsa ./ssh/ && chmod 600 ./ssh/id_rsa

# 3. Build and Run
docker compose up --build -d

# 4. Access
# Open the Init PWA (recommended for mobile)
open http://localhost:7777/init/
# Or the full OpenCode editor
open http://localhost:7777/
```

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
1. **Payload URL**: `https://your-openmoco-domain.com/webhooks/github`
2. **Content type**: `application/json`
3. **Secret**: Matches your `GITHUB_WEBHOOK_SECRET`
4. **Events**: `push`, `workflow_run`, `pull_request`

## Usage

### Managing Repositories
Open the Init PWA and tap the gear icon ⚙️. Search for your GitHub repos and tap "Enable". OpenMoco will handle cloning in the background.

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
- `mise_data` (volume): Installed languages and toolchains.

## License
Provided as-is for personal and commercial use.
