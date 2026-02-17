FROM node:alpine

# Install git and ssh
RUN apk add --no-cache git openssh-client bash

# Install OpenCode globally
RUN npm i -g opencode-ai@latest

# Create workspace directory
RUN mkdir -p /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Expose OpenCode default port (adjust if different)
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]