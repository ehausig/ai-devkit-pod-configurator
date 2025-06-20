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
CONFIG_DIR="/home/devuser/.config/claude-code"
mkdir -p "$CONFIG_DIR"
mkdir -p /home/devuser/workspace
mkdir -p /home/devuser/workspace/.claude
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

# Copy project CLAUDE.md to workspace/.claude if it exists
if [ -f /tmp/project-CLAUDE.md ]; then
    echo "Found project CLAUDE.md, copying to workspace/.claude..."
    if [ ! -f /home/devuser/workspace/.claude/CLAUDE.md ]; then
        cp /tmp/project-CLAUDE.md /home/devuser/workspace/.claude/CLAUDE.md
        echo "Project CLAUDE.md copied successfully"
    else
        echo "CLAUDE.md already exists in workspace/.claude"
    fi
fi

# Copy all component markdown files to workspace/.claude
echo "Copying component documentation files..."
for md_file in /tmp/*.md; do
    if [ -f "$md_file" ] && [ "$md_file" != "/tmp/project-CLAUDE.md" ] && [ "$md_file" != "/tmp/user-CLAUDE.md" ]; then
        basename_file=$(basename "$md_file")
        if [ ! -f "/home/devuser/workspace/.claude/$basename_file" ]; then
            cp "$md_file" "/home/devuser/workspace/.claude/$basename_file"
            echo "Copied $basename_file to workspace/.claude"
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
touch "$BASHRC"

# COMPONENT_SETUP_PLACEHOLDER

# Ensure proper ownership of essential directories
chown -R devuser:devuser /home/devuser/workspace 2>/dev/null || true
chown -R devuser:devuser /home/devuser/workspace/.claude 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.config/claude-code 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.local 2>/dev/null || true

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

# Add welcome message to .bashrc
if ! grep -q "AI Development Kit Welcome" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# AI Development Kit Welcome Message
if [ -n "$PS1" ] && [ -z "$DEVKIT_WELCOME_SHOWN" ]; then
    export DEVKIT_WELCOME_SHOWN=1
    echo ""
    echo "Welcome to AI Development Kit! 🚀"
    echo ""
    
    # Check if SSH is available
    if pgrep -x sshd > /dev/null 2>&1; then
        echo "  📡 SSH is running - connect via port 2222"
        echo "     Initial password: devuser (please change with 'passwd')"
    fi
    
    echo ""
    echo "Quick Start:"
    # Check if Claude Code is installed
    if command -v claude &> /dev/null 2>&1; then
        echo "  • claude           - Start Claude Code"
        echo "  • claude --help    - Show available commands"
    fi
    echo "  • tree             - View directory structure"
    echo ""
    # Check if git is configured
    GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
    if [ -z "$GIT_NAME" ]; then
        echo "  ⚠️  Git not configured - run 'setup-git.sh' to configure"
        echo ""
    else
        echo "  ✓ Git configured as: $GIT_NAME"
        echo ""
    fi
    if [ -f ~/.claude/CLAUDE.md ]; then
        echo "User memory loaded: ~/.claude/CLAUDE.md"
    fi
    if [ -f ~/workspace/.claude/CLAUDE.md ]; then
        echo "Project memory loaded: ~/workspace/.claude/CLAUDE.md"
        echo "  • cat ~/workspace/.claude/CLAUDE.md - View component imports"
        echo ""
    fi
fi

# Clear any input buffer to prevent command execution
if [ -n "$PS1" ]; then
    # Clear the input buffer
    read -t 0.1 -n 10000 discard 2>/dev/null || true
fi
EOF
fi

# Add password change reminder for SSH users
if ! grep -q "SSH_PASSWORD_REMINDER" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# SSH Password Change Reminder
if [ -n "$SSH_CONNECTION" ] && [ -z "$SSH_PASSWORD_CHANGED" ]; then
    if [ "$(sudo grep devuser /etc/shadow | cut -d: -f2)" = "$(sudo grep devuser /etc/shadow.backup 2>/dev/null | cut -d: -f2)" ]; then
        echo ""
        echo "⚠️  SECURITY REMINDER: Please change your password with 'passwd'"
        echo ""
    fi
fi
EOF
fi

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
