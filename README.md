![OpenMoco Screenshot](screenshot.png)

# OpenMoco (Mobile Coding)

> Code, debug, and deploy from anywhere using AI agents.

A self-hosted, mobile-first development environment that lets you go from idea → agent → production entirely from your phone, without needing your laptop.

## For Developers

**What is this?**  

OpenMoco is a bundled version of [OpenCode](https://opencode.ai/) meant for running on your own VPS and accessing through its Web UI.

You get agentic coding ([OpenCode Zen](https://opencode.ai/zen)'s free models, [Ollama Cloud](https://ollama.com/search?c=cloud)'s free models, [Google AI Studio](https://aistudio.google.com)'s free models - or any of the others),
a terminal, file browser. Just install on a system with Docker and reverse proxy it through nginx.

**Why use it?**  
- Code from your phone, tablet, Chromebook, any browser
- Persistent toolchains (Python, Node, Go, etc.) via [Mise](https://mise.jdx.dev/)
- Your data, your server — no required third-party cloud dependencies
- OpenCode with the [Conductor plugin](https://github.com/Jonkimi/create-conductor-flow) for structured agentic workflows
- Full terminal access when you need it

**How to use it**  
1. Clone to your VPS
2. Set values in .env and optionally clone projects to ./workspace (you can also do that manually later)
3. Run `docker compose up -d`
4. Access via browser either at `http://your-vps:7777` or use nginx and something like `https://openmoco.your-vps.com`
5. Tell the agent what to build — it clones repos, writes code, runs tests, and commits and pushes changes for you

**Requirements**: A VPS with Docker installed and git repo access.

## Quick Setup

```bash
# 1. Clone and configure
cp .env.example .env
cp config/repos.txt.example config/repos.txt
nano .env  # Set GIT_USER_NAME and GIT_USER_EMAIL
nano config/repos.txt  # Add your repos

# 2. Add SSH keys (optional - for SSH-based git URLs)
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
To install or use a specific version of a language (run these in the OpenCode terminal):
```bash
mise use python@3.12
mise use go@latest
mise use node@22
```

To see what's available:
```bash
mise ls-remote
```

The environment is configured to automatically activate these tools in your shell sessions.

## Managing Projects

Projects are cloned into the `/workspace` directory. You can add repos in two ways:

### Pre-configured Repos
Add repo URLs to `config/repos.txt` (one per line):
```
git@github.com:user/repo.git
https://github.com/user/repo.git
```
They'll be cloned automatically on container start.

### Manual Cloning
Shell into the container and use git directly:
```bash
docker compose exec opencode bash
cd /workspace
# HTTPS with token
git clone https://x-access-token:YOUR_TOKEN@github.com/user/repo.git
# Or SSH (if you've added your SSH key)
git clone git@github.com:user/repo.git
```

### Creating New Projects
Scaffold new projects from scratch using `mise` and standard build tools:
```bash
mkdir /workspace/my-new-app
cd /workspace/my-new-app && git init
mise use node@latest
```

### Removing Projects
To save disk space, simply remove the directory from the workspace.

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
