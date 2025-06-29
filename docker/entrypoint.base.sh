#!/bin/bash
set -e

# Core PATH setup - only essential paths
export PATH="$PATH:/usr/local/bin"

# Source all profile scripts to load language paths
if [ -d /etc/profile.d ]; then
    for i in /etc/profile.d/*.sh; do
        if [ -r $i ]; then
            . $i
        fi
    done
fi

# Create essential directories that are always needed
CONFIG_DIR="/home/devuser/.config/ai-devkit"
mkdir -p "$CONFIG_DIR"
mkdir -p /home/devuser/workspace
mkdir -p /home/devuser/.claude
mkdir -p /home/devuser/.local/bin

# Start SSH daemon if host keys are mounted
echo "Checking for SSH host keys..."
if [ -d /etc/ssh/mounted_keys ] && [ -f /etc/ssh/mounted_keys/ssh_host_rsa_key ]; then
    echo "Found mounted SSH host keys, starting SSH daemon..."
    # Ensure proper permissions on mounted keys
    chmod 600 /etc/ssh/mounted_keys/ssh_host_*_key 2>/dev/null || true
    chmod 644 /etc/ssh/mounted_keys/ssh_host_*_key.pub 2>/dev/null || true
    
    # Start SSH daemon
    /usr/sbin/sshd -D &
    echo "SSH daemon started on port 22"
else
    echo "No mounted SSH host keys found, SSH daemon not started"
    echo "To enable SSH access, mount host keys to /etc/ssh/mounted_keys/"
fi

# Handle git configuration from mounted secrets
echo "Checking for pre-configured git settings..."
GIT_CONFIGURED=false

# Check if .gitconfig was mounted from secret
if [ -f /tmp/git-mounted/.gitconfig ]; then
    echo "Found mounted git configuration"
    GIT_CONFIGURED=true
    
    # Copy to home directory with proper ownership
    cp /tmp/git-mounted/.gitconfig /home/devuser/.gitconfig
    chown devuser:devuser /home/devuser/.gitconfig
    chmod 600 /home/devuser/.gitconfig
fi

# Handle git credentials
if [ -f /tmp/git-mounted/.git-credentials ]; then
    echo "Found mounted git credentials"
    cp /tmp/git-mounted/.git-credentials /home/devuser/.git-credentials
    chown devuser:devuser /home/devuser/.git-credentials
    chmod 600 /home/devuser/.git-credentials
fi

# Handle GitHub CLI configuration
if [ -f /tmp/git-mounted/gh-hosts.yml ]; then
    echo "Found mounted GitHub CLI configuration"
    mkdir -p /home/devuser/.config/gh
    cp /tmp/git-mounted/gh-hosts.yml /home/devuser/.config/gh/hosts.yml
    chown -R devuser:devuser /home/devuser/.config/gh
    chmod 600 /home/devuser/.config/gh/hosts.yml
fi

# Copy user-CLAUDE.md to ~/.claude/CLAUDE.md if it exists
# TODO: incorporate Claude Code specific configuration in components/agents files
if [ -f /tmp/user-CLAUDE.md ]; then
    echo "Found user CLAUDE.md, copying to ~/.claude..."
    cp /tmp/user-CLAUDE.md /home/devuser/.claude/CLAUDE.md
    echo "User CLAUDE.md copied successfully"
    
    # Append component imports to the CLAUDE.md file
    if [ -f /tmp/component-imports.txt ]; then
        echo "Appending component imports to CLAUDE.md..."
        cat /tmp/component-imports.txt >> /home/devuser/.claude/CLAUDE.md
        echo "Component imports appended successfully"
    fi
fi

# Copy all component markdown files to ~/.claude
# TODO: maybe put in generic ~/.prompts directory, then use symlink for .claude?
echo "Copying component documentation files..."
for md_file in /tmp/*.md; do
    if [ -f "$md_file" ] && [ "$md_file" != "/tmp/user-CLAUDE.md" ]; then
        basename_file=$(basename "$md_file")
        if [ ! -f "/home/devuser/.claude/$basename_file" ]; then
            cp "$md_file" "/home/devuser/.claude/$basename_file"
            echo "Copied $basename_file to ~/.claude"
        fi
    fi
done

# Function to add line to file if not already present
add_if_not_exists() {
    local line="$1"
    local file="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Configure .bashrc for devuser - only essential setup
BASHRC="/home/devuser/.bashrc"

# COMPONENT_SETUP_PLACEHOLDER

# Ensure proper ownership of essential directories
chown -R devuser:devuser /home/devuser/workspace 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.claude 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.config/ai-devkit 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.local 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.tui-test-templates 2>/dev/null || true

# Add user's local bin to PATH
add_if_not_exists 'export PATH="$HOME/.local/bin:$PATH"' "$BASHRC"

# Add terminal configuration for better CLI support
add_if_not_exists 'export TERM=xterm-256color' "$BASHRC"
add_if_not_exists 'export FORCE_COLOR=1' "$BASHRC"
add_if_not_exists 'export CI=false' "$BASHRC"

# Automatically cd to workspace on login
add_if_not_exists 'cd ~/workspace 2>/dev/null || true' "$BASHRC"

# Set a custom prompt
add_if_not_exists 'export PS1="\[\033[01;32m\]devuser@ai-devkit\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ "' "$BASHRC"

# Source system-wide profile scripts
if ! grep -q "Source system-wide profile scripts" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# Source system-wide profile scripts
if [ -d /etc/profile.d ]; then
    for i in /etc/profile.d/*.sh; do
        if [ -r $i ]; then
            . $i
        fi
    done
fi
EOF
fi

# Ensure proper ownership of .bashrc
chown devuser:devuser "$BASHRC"

# Remove the old welcome message from .bashrc since we now use MOTD
# (No need to add welcome message to .bashrc anymore)

# Create shadow backup for password change detection
if [ ! -f /etc/shadow.backup ]; then
    cp /etc/shadow /etc/shadow.backup
fi

# Switch to devuser and execute the command
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, preparing to switch to devuser..."
    # If no command specified, sleep indefinitely
    if [ $# -eq 0 ]; then
        echo "No command specified, running sleep infinity to keep container alive..."
        exec sleep infinity
    else
        echo "Switching to devuser to run: $*"
        # Build environment preservation string dynamically
        ENV_PRESERVE="export TERM='$TERM' && export FORCE_COLOR='$FORCE_COLOR' && export CI='$CI'"
        
        # Add component-specific environment variables if they exist
        [ -n "$PIP_INDEX_URL" ] && ENV_PRESERVE="$ENV_PRESERVE && export PIP_INDEX_URL='$PIP_INDEX_URL'"
        [ -n "$PIP_TRUSTED_HOST" ] && ENV_PRESERVE="$ENV_PRESERVE && export PIP_TRUSTED_HOST='$PIP_TRUSTED_HOST'"
        [ -n "$NPM_CONFIG_REGISTRY" ] && ENV_PRESERVE="$ENV_PRESERVE && export NPM_CONFIG_REGISTRY='$NPM_CONFIG_REGISTRY'"
        [ -n "$GOPROXY" ] && ENV_PRESERVE="$ENV_PRESERVE && export GOPROXY='$GOPROXY'"
        [ -n "$CARGO_REGISTRIES_CRATES_IO_PROTOCOL" ] && ENV_PRESERVE="$ENV_PRESERVE && export CARGO_REGISTRIES_CRATES_IO_PROTOCOL='$CARGO_REGISTRIES_CRATES_IO_PROTOCOL'"
        [ -n "$CARGO_HTTP_CHECK_REVOKE" ] && ENV_PRESERVE="$ENV_PRESERVE && export CARGO_HTTP_CHECK_REVOKE='$CARGO_HTTP_CHECK_REVOKE'"
        [ -n "$CARGO_NET_GIT_FETCH_WITH_CLI" ] && ENV_PRESERVE="$ENV_PRESERVE && export CARGO_NET_GIT_FETCH_WITH_CLI='$CARGO_NET_GIT_FETCH_WITH_CLI'"
        [ -n "$NO_PROXY" ] && ENV_PRESERVE="$ENV_PRESERVE && export NO_PROXY='$NO_PROXY'"
        [ -n "$no_proxy" ] && ENV_PRESERVE="$ENV_PRESERVE && export no_proxy='$no_proxy'"
        [ -n "$SBT_OPTS" ] && ENV_PRESERVE="$ENV_PRESERVE && export SBT_OPTS='$SBT_OPTS'"
        
        exec su - devuser -c "$ENV_PRESERVE && $*"
    fi
else
    echo "Running as non-root user..."
    if [ $# -eq 0 ]; then
        echo "No command specified, running sleep infinity..."
        exec sleep infinity
    else
        exec "$@"
    fi
fi
