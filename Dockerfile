FROM node:bookworm-slim

# Install git, ssh, build tools, and other essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    bash \
    jq \
    curl \
    ca-certificates \
    build-essential \
    libssl-dev \
    pkg-config \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Install GitLab CLI (glab)
RUN curl -sSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash \
    && apt-get update && apt-get install -y glab && rm -rf /var/lib/apt/lists/*

# Install mise (replaces asdf) for language and tool version management
RUN curl https://mise.run | sh
ENV PATH="/root/.local/share/mise/bin:/root/.local/share/mise/shims:$PATH"

# Install OpenCode globally
RUN npm i -g opencode-ai@latest

# Install Conductor plugin for OpenCode
RUN CI=true npx create-conductor-flow --agent opencode --scope global --git-ignore none

# Create workspace directory
RUN mkdir -p /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Expose OpenCode default port (adjust if different)
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]