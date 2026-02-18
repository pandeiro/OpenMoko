FROM node:bookworm-slim

# Install git and ssh
RUN apt-get update && apt-get install -y --no-install-recommends git openssh-client bash jq && rm -rf /var/lib/apt/lists/*

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