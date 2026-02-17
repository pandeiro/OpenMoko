# OpenMoco (Mobile Coding)

**What It Is**:

Simple, secure, mobile-first agentic coding where you can go from idea → agent → production entirely from your phone, without needing your laptop

**What You Need**:

A VPS with Docker installed and the means to access to your git repos

**Current Status**:

Working: Creates a containerized [OpenCode](https://github.com/anomalyco/opencode) environment with automatic repository cloning and git configuration.

---

## Features

- 🚀 Auto-clones repositories from a config file on startup
- 🔄 Auto-pulls latest changes if repos already exist
- 🔑 SSH key support for git authentication
- 🤖 Configurable git identity (for agent commits)
- 🐳 Lightweight Alpine-based image
- 🔒 Localhost-only exposure by default

## Prerequisites

- Docker and Docker Compose installed
- SSH key for GitHub/GitLab access (or use HTTPS with tokens)
- A VPS or local machine to run the container

## Quick Start

### 1. Clone Project

### 2. Create Required Files

Customize and rename required files:
- `.env.example` → `.env`
- `config/repos.txt.example` → `config/repos.txt`
- `ssh` → add your keys

### 3. Configure Environment Variables

Copy the example and edit:

```bash
cp .env.example .env
nano .env
```

Edit `.env`:
```bash
GIT_USER_NAME=your-user-agent
GIT_USER_EMAIL=email@yourproject.dev
```

### 4. Set Up SSH Keys

**Option A: Use existing SSH key**
```bash
cp ~/.ssh/id_rsa ./ssh/
cp ~/.ssh/id_rsa.pub ./ssh/
chmod 600 ./ssh/id_rsa
```

**Option B: Generate dedicated key for this agent**
```bash
ssh-keygen -t ed25519 -f ./ssh/id_ed25519 -C "opencode-agent"
# Add the public key to GitHub: Settings → SSH Keys
cat ./ssh/id_ed25519.pub
```

### 5. Configure Repositories

Copy and edit the repos list:

```bash
cp repos.txt.example config/repos.txt
nano config/repos.txt
```

Add your repositories (one per line):
```
git@github.com:yourusername/project1.git
git@github.com:yourusername/project2.git
```

### 6. Run

```bash
docker compose up -d

# Check logs if you want
docker compose logs -f
```

### 7. Access OpenCode

Open your browser and navigate to:
```
http://localhost:7777
```

Or if exposing via nginx/Tailscale:
```
https://opencode.yourdomain.com
```

## Configuration Details

### Environment Variables (.env)

| Variable | Description | Example |
|----------|-------------|---------|
| `GIT_USER_NAME` | Git commit author name | `agent-bot` |
| `GIT_USER_EMAIL` | Git commit author email | `agent@project.dev` |
| `OPENCODE_SERVER_PASSWORD` | Password for OpenCode web UI | `secure_password_123`

Optional Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OLLAMA_API_KEY` | Ollama Cloud API Key | xyz |

If you supply `OLLAMA_API_KEY`, the setup script will include Ollama as a model
provider for OpenCode.

### Repository List (config/repos.txt)

Format: One repository URL per line

**SSH format (recommended):**
```
git@github.com:user/repo.git
```

**HTTPS format (if using tokens):**
```
https://github.com/user/repo.git
```

**Comments:** Lines starting with `#` are ignored
```
# This is a comment
git@github.com:user/repo.git  # This repo will be cloned
```

### Directory Volumes

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `./workspace` | `/workspace` | Where repos are cloned (read-write) |
| `./ssh` | `/root/.ssh` | SSH keys for git auth (read-only) |
| `./config` | `/config` | Configuration files like repos.txt (read-only) |

## Daily Workflow

### Adding a New Repository

1. Edit `config/repos.txt`:
   ```bash
   nano config/repos.txt
   # Add new repo URL
   ```

2. Restart container to clone new repos:
   ```bash
   docker compose restart
   ```

3. Or manually clone inside container:
   ```bash
   docker compose exec opencode git clone git@github.com:user/newrepo.git /workspace/newrepo
   ```

### Updating Repositories

Repositories are automatically pulled on container startup. To manually update:

```bash
docker compose exec opencode bash
cd /workspace/your-repo
git pull
```

### Making Changes

1. Access OpenCode at `http://localhost:7777`
2. Make changes via the web interface
3. OpenCode will use the configured git identity for commits
4. Push changes via OpenCode or manually:
   ```bash
   docker compose exec opencode bash
   cd /workspace/your-repo
   git push
   ```

## Exposing OpenCode Securely

### Option A: Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/opencode
server {
    listen 443 ssl;
    server_name opencode.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Then:
```bash
ln -s /etc/nginx/sites-available/opencode /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### Option B: Tailscale (Recommended for Security)

1. Install Tailscale on VPS:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up
   ```

2. Update docker-compose.yml to expose on all interfaces:
   ```yaml
   ports:
     - "7777:8080"  # Remove 127.0.0.1 restriction
   ```

3. Access via Tailscale IP:
   ```
   http://100.x.x.x:7777
   ```

### Option C: SSH Tunnel (Quick and Secure)

From your local machine:
```bash
ssh -L 7777:localhost:7777 user@your-vps
# Access at http://localhost:7777 on your local machine
```

## Troubleshooting

### Container won't start

Check logs:
```bash
docker compose logs opencode
```

Common issues:
- SSH key permissions (must be 600)
- Invalid repos.txt format
- Git authentication failure

### Git authentication fails

Check SSH key setup:
```bash
docker compose exec opencode ssh -T git@github.com
# Should see: "Hi username! You've successfully authenticated..."
```

If using HTTPS, ensure your token is in the URL:
```
https://username:TOKEN@github.com/user/repo.git
```

### Repository won't clone

Check repos.txt format:
```bash
cat config/repos.txt
# Ensure no Windows line endings (CRLF)
# Convert if needed:
dos2unix config/repos.txt
```

Manually test clone:
```bash
docker compose exec opencode bash
git clone git@github.com:user/repo.git /tmp/test
```

### OpenCode not accessible

Check if container is running:
```bash
docker compose ps
```

Check port binding:
```bash
netstat -tlnp | grep 8080
```

Check firewall:
```bash
sudo ufw status
# If needed: sudo ufw allow 8080/tcp
```

## Security Best Practices

1. **Use dedicated SSH key** - Don't use your personal key
2. **Read-only mounts** - SSH keys are mounted read-only
3. **Localhost binding** - Default config only exposes to 127.0.0.1
4. **Use Tailscale** - For secure remote access without public exposure
5. **Regular updates** - Keep OpenCode and base image updated
6. **Monitor git activity** - Enable GitHub notifications for pushes

## Maintenance

### Update OpenCode

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Backup Workspace

```bash
tar -czf workspace-backup-$(date +%Y%m%d).tar.gz workspace/
```

### Clean Up Old Repos

```bash
# Remove repos no longer in repos.txt
docker compose exec opencode bash
cd /workspace
# Manually delete unwanted directories
```

## Customization

### Change OpenCode Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "127.0.0.1:3000:8080"  # Host:Container
```

Then update your nginx/access method accordingly.

### Add Custom Git Config

Create `gitconfig` file:
```ini
[user]
    name = agent-bot
    email = agent@project.dev
[core]
    editor = nano
[pull]
    rebase = false
```

Mount it in `docker-compose.yml`:
```yaml
volumes:
  - ./gitconfig:/root/.gitconfig:ro
```

### Run Commands on Startup

Edit `entrypoint.sh` to add custom initialization:
```bash
# Before launching OpenCode
echo "Running custom setup..."
# Your commands here
```

## Support

For issues with:
- **This Docker setup**: Check logs and troubleshooting section above
- **OpenCode itself**: See [OpenCode documentation](https://github.com/anomalyco/opencode)
- **Git/GitHub**: See [GitHub docs](https://docs.github.com)

## License

This Docker configuration is provided as-is for personal and commercial use.
