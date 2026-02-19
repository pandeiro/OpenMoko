# OpenMoco (Mobile Coding)

Simple, secure, mobile-first agentic coding where you can go from idea → agent → production entirely from your phone, without needing your laptop.

**Requirements**: A VPS with Docker installed and git repo access.

## Quick Setup

```bash
# 1. Clone and configure
cp .env.example .env
cp config/repos.txt.example config/repos.txt
nano .env  # Set GIT_USER_NAME and GIT_USER_EMAIL
nano config/repos.txt  # Add your repos

# 2. Add SSH keys
cp ~/.ssh/id_rsa ./ssh/ && chmod 600 ./ssh/id_rsa

# 3. Run
docker compose up -d

# 4. Access
open http://localhost:7777
```

## Configuration

### Environment Variables (.env)
| Variable | Description |
|----------|-------------|
| `GIT_USER_NAME` | Git commit author name |
| `GIT_USER_EMAIL` | Git commit author email |
| `OPENCODE_SERVER_PASSWORD` | Web UI password |
| `OLLAMA_API_KEY` | Ollama Cloud API key (optional) |
| `GOOGLE_AI_STUDIO_API_KEY` | Google AI Studio key (optional) |

### Repositories (config/repos.txt)
One repo URL per line. Lines starting with `#` are comments.
```
git@github.com:user/repo.git
https://github.com/user/repo.git  # with token in URL
```

### Volumes
| Host | Container | Purpose |
|------|-----------|---------|
| `./workspace` | `/workspace` | Cloned repos (read-write) |
| `./ssh` | `/root/.ssh` | SSH keys (read-only) |
| `./config` | `/config` | Config files (read-only) |
| `mise_data` | `/root/.local/share/mise` | Persistent toolchain (languages/tools) |

## Managing Stacks & Tools

OpenMoco uses **Mise** (a modern `asdf` replacement) for multi-stack toolchain management. This allows the environment to persist languages (Python, Go, Node, etc.) and CLI tools across container restarts and redeployments.

### How it works
- **Persistence**: Tools are installed into a persistent Docker volume (`mise_data`).
- **Dynamic**: The agent (or you) can provision any tool on the fly.
- **Base Layer**: Common build dependencies (`build-essential`, `libssl-dev`) are pre-installed in the image to support compiling tools if needed.

### Usage
To install or use a specific version of a language:
```bash
docker compose exec opencode mise use python@3.12
docker compose exec opencode mise use go@latest
docker compose exec opencode mise use node@22
```

To see what's available:
```bash
docker compose exec opencode mise ls-remote
```

The environment is configured to automatically activate these tools in your shell sessions.

## Managing Projects

OpenMoco provides built-in support for **GitHub CLI (`gh`)** and **GitLab CLI (`glab`)** to make it easy to clone, manage, and remove projects dynamically.

### Adding Projects (Clone)
Login once to persist your credentials:
```bash
docker compose exec opencode gh auth login
docker compose exec opencode glab auth login
```

List and clone repositories directly into the workspace:
```bash
# GitHub
docker compose exec opencode gh repo list
docker compose exec opencode gh repo clone user/repo

# GitLab
docker compose exec opencode glab repo list
docker compose exec opencode glab repo clone user/repo
```

### Creating New Projects
You can scaffold new projects from scratch using `mise` and standard build tools:
```bash
docker compose exec opencode mkdir /workspace/my-new-app
docker compose exec opencode cd /workspace/my-new-app && git init
docker compose exec opencode mise use node@latest
```

### Removing Projects
To save disk space, simply remove the directory from the workspace. Since configurations for `gh` and `glab` are persisted in Docker volumes, you won't need to re-authenticate when you come back.

## Daily Use

```bash
# Add new repos
echo "git@github.com:user/newrepo.git" >> config/repos.txt
docker compose restart

# Update all repos
docker compose restart

# Access
docker compose logs -f  # View logs
docker compose exec opencode bash  # Shell into container
```

## Access Remotely

**Option A: Tailscale** (recommended)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
# Edit docker-compose.yml: change "127.0.0.1:7777:8080" to "7777:8080"
docker compose restart
# Access at http://<tailscale-ip>:7777
```

**Option B: SSH tunnel**
```bash
ssh -L 7777:localhost:7777 user@vps
```

## Troubleshooting

```bash
# Check container status
docker compose logs -f

# Test GitHub auth
docker compose exec opencode ssh -T git@github.com

# Verify repos
docker compose exec opencode ls -la /workspace
```

For more details, see the full documentation in the wiki.

## License

Provided as-is for personal and commercial use.
