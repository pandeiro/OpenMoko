#!/bin/bash
set -e

# Check for required password
if [ -z "$OPENCODE_SERVER_PASSWORD" ]; then
    echo "ERROR: OPENCODE_SERVER_PASSWORD environment variable is not set!"
    echo "Please set OPENCODE_SERVER_PASSWORD in your .env file"
    exit 1
fi

# Configure git from environment variables
if [ -n "$GIT_USER_NAME" ]; then
    git config --global user.name "$GIT_USER_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
fi

# Configure Ollama provider if API key is present
if [ -n "$OLLAMA_API_KEY" ]; then
    echo "Ollama API key detected, configuring OpenCode provider..."
    
    CONFIG_DIR="$HOME/.config/opencode"
    CONFIG_FILE="$CONFIG_DIR/opencode.json"
    
    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    
    # Check if config file exists
    if [ -f "$CONFIG_FILE" ]; then
        # Config exists, check if ollama provider already configured
        if grep -q '"ollama"' "$CONFIG_FILE"; then
            echo "Ollama provider already configured in opencode.json"
        else
            # Add ollama provider to existing config
            echo "Adding Ollama provider to existing config..."
            # Use jq to merge the ollama provider
            TEMP_FILE=$(mktemp)
            jq '.provider.ollama = {
              "npm": "@ai-sdk/openai-compatible",
              "name": "Ollama Cloud",
              "options": {
                "baseURL": "https://ollama.com/v1"
              },
              "models": {
                "glm-5:cloud": {
                  "_launch": true,
                  "name": "glm-5:cloud"
                },
                "qwen3-coder:480b-cloud": {
                  "name": "qwen3-coder:480b-cloud"
                }
              }
            }' "$CONFIG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
        fi
    else
        # Config doesn't exist, create it with ollama provider
        echo "Creating opencode.json with Ollama provider..."
        cat > "$CONFIG_FILE" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama Cloud",
      "options": {
        "baseURL": "https://ollama.com/v1"
      },
      "models": {
        "glm-5:cloud": {
          "_launch": true,
          "name": "glm-5:cloud"
        },
        "qwen3-coder:480b-cloud": {
          "name": "qwen3-coder:480b-cloud"
        }
      }
    }
  }
}
EOF
    fi
fi

# Configure Google AI Studio provider if API key is present
if [ -n "$GOOGLE_AI_STUDIO_API_KEY" ]; then
    echo "Google AI Studio API key detected, configuring OpenCode provider..."
    
    CONFIG_DIR="$HOME/.config/opencode"
    CONFIG_FILE="$CONFIG_DIR/opencode.json"
    
    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    
    # Check if config file exists
    if [ -f "$CONFIG_FILE" ]; then
        # Config exists, check if google provider already configured
        if grep -q '"google"' "$CONFIG_FILE"; then
            echo "Google provider already configured in opencode.json"
        else
            # Add google provider to existing config
            echo "Adding Google provider to existing config..."
            TEMP_FILE=$(mktemp)
            jq '.provider.google = {
              "options": {
                "apiKey": "'"$GOOGLE_AI_STUDIO_API_KEY"'",
                "baseURL": "https://generativelanguage.googleapis.com/v1beta"
              }
            }' "$CONFIG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
        fi
    else
        # Config doesn't exist, create it with google provider
        echo "Creating opencode.json with Google provider..."
        cat > "$CONFIG_FILE" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "google": {
      "options": {
        "apiKey": "${GOOGLE_AI_STUDIO_API_KEY}",
        "baseURL": "https://generativelanguage.googleapis.com/v1beta"
      }
    }
  }
}
EOF
    fi
fi

# Set up SSH for git (if SSH keys are mounted)
if [ -d "/root/.ssh" ]; then
    # Directory is mounted read-only, so we can't chmod it
    # But we can check file permissions
    if [ -f "/root/.ssh/id_rsa" ]; then
        # Check if permissions are correct (should be 600)
        PERMS=$(stat -c %a "/root/.ssh/id_rsa" 2>/dev/null || stat -f %OLp "/root/.ssh/id_rsa" 2>/dev/null)
        if [ "$PERMS" != "600" ]; then
            echo "Warning: /root/.ssh/id_rsa has permissions $PERMS (should be 600)"
            echo "Please fix on host: chmod 600 ./ssh/id_rsa"
        fi
    fi
    if [ -f "/root/.ssh/id_ed25519" ]; then
        PERMS=$(stat -c %a "/root/.ssh/id_ed25519" 2>/dev/null || stat -f %OLp "/root/.ssh/id_ed25519" 2>/dev/null)
        if [ "$PERMS" != "600" ]; then
            echo "Warning: /root/.ssh/id_ed25519 has permissions $PERMS (should be 600)"
            echo "Please fix on host: chmod 600 ./ssh/id_ed25519"
        fi
    fi
    
    # Add GitHub to known_hosts to avoid prompt
    mkdir -p /tmp/.ssh
    ssh-keyscan github.com >> /tmp/.ssh/known_hosts 2>/dev/null
    ssh-keyscan gitlab.com >> /tmp/.ssh/known_hosts 2>/dev/null
    
    # Merge with mounted known_hosts if it exists
    if [ -f "/root/.ssh/known_hosts" ]; then
        cat /root/.ssh/known_hosts >> /tmp/.ssh/known_hosts 2>/dev/null
    fi
    
    # Point SSH to use our writable known_hosts
    export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/tmp/.ssh/known_hosts -o StrictHostKeyChecking=accept-new"
fi

# Note: Repo cloning is now handled by the openmoko-events service
# via the Init repo management UI. No repos.txt needed.

# Set up custom PS1 and mise initialization
cat > /root/.bashrc <<'EOF'
# MoCo shell initialization
export PATH="/root/.local/bin:/root/.local/share/mise/bin:/root/.local/share/mise/shims:$PATH"
eval "$(mise activate bash)"

# Custom MoCo PS1
parse_git_status() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return
    fi
    
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
    local status=$(git status --porcelain 2>/dev/null)
    local output=""
    
    # Check for staged changes
    if echo "$status" | grep -q "^M"; then
        output+="*"
    fi
    if echo "$status" | grep -q "^A"; then
        output+="+"
    fi
    # Check for unstaged changes
    if echo "$status" | grep -q "^.M"; then
        output+="~"
    fi
    # Check for untracked files
    if echo "$status" | grep -q "^??"; then
        output+="?"
    fi
    
    if [ -n "$branch" ]; then
        echo " ($branch${output})"
    fi
}

PS1='\[\033[01;32m\]\t\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\[\033[01;33m\]$(parse_git_status)\[\033[00m\]\n\$ '
EOF

# Launch OpenCode
echo "Starting OpenCode web server..."
echo "  Port: 8080"
echo "  Hostname: 0.0.0.0 (accessible from outside container)"
echo "  Password auth: ${OPENCODE_SERVER_PASSWORD:+enabled}${OPENCODE_SERVER_PASSWORD:-disabled}"
echo ""
exec opencode web --port 8080 --hostname 0.0.0.0
