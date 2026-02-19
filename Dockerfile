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
    && rm -rf /var/lib/apt/lists/*

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