#!/bin/bash
set -e

# Ensure PATH includes npm global binaries (if npm is installed)
export PATH="$PATH:/usr/local/bin"
if [ -d "/usr/lib/node_modules/.bin" ]; then
    export PATH="$PATH:/usr/lib/node_modules/.bin"
fi

# Source all profile scripts to load language paths
if [ -d /etc/profile.d ]; then
    for i in /etc/profile.d/*.sh; do
        if [ -r $i ]; then
            . $i
        fi
    done
fi

# Create config directory if it doesn't exist
CONFIG_DIR="/home/devuser/.config/claude-code"
mkdir -p "$CONFIG_DIR"

# Create .local/bin directory for user pip installs
mkdir -p /home/devuser/.local/bin

# Create .npm-global directory for user npm installs (if npm is available)
if command -v npm &> /dev/null; then
    mkdir -p /home/devuser/.npm-global
fi

# Create .cargo directory for Rust/Cargo if it doesn't exist
mkdir -p /home/devuser/.cargo

# Create .m2 directory for Maven if it doesn't exist
mkdir -p /home/devuser/.m2

# Create .sbt directory for SBT if it doesn't exist
mkdir -p /home/devuser/.sbt
mkdir -p /home/devuser/.sbt/0.13
mkdir -p /home/devuser/.sbt/1.0
mkdir -p /home/devuser/.sbt/boot

# Create .gradle directory for Gradle if it doesn't exist
mkdir -p /home/devuser/.gradle

# Create .claude directory for global Claude configuration (if Claude Code is installed)
if command -v claude &> /dev/null 2>&1 || [ -f /tmp/CLAUDE.md ]; then
    mkdir -p /home/devuser/.claude
fi

# Create .claude directory in workspace for project-specific settings (if Claude Code is installed)
if command -v claude &> /dev/null 2>&1 || [ -f /tmp/settings.local.json.template ]; then
    mkdir -p /home/devuser/workspace/.claude
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

# Copy settings.local.json from template if it exists (Claude Code component)
echo "Checking for settings.local.json..."
if [ -f /tmp/settings.local.json.template ]; then
    echo "Found /tmp/settings.local.json.template"
    if [ ! -f /home/devuser/workspace/.claude/settings.local.json ]; then
        echo "Copying settings.local.json to workspace/.claude folder..."
        cp /tmp/settings.local.json.template /home/devuser/workspace/.claude/settings.local.json
        echo "settings.local.json copied successfully to /home/devuser/workspace/.claude/"
    else
        echo "settings.local.json already exists in workspace/.claude folder"
    fi
else
    echo "No /tmp/settings.local.json.template found in image"
fi

# Copy CLAUDE.md to .claude folder if it exists in the image but not in the mounted volume
echo "Checking for CLAUDE.md..."
if [ -f /tmp/CLAUDE.md ]; then
    echo "Found /tmp/CLAUDE.md"
    if [ ! -f /home/devuser/.claude/CLAUDE.md ]; then
        echo "Copying CLAUDE.md to .claude folder..."
        cp /tmp/CLAUDE.md /home/devuser/.claude/CLAUDE.md
        echo "CLAUDE.md copied successfully to /home/devuser/.claude/"
    else
        echo "CLAUDE.md already exists in .claude folder"
    fi
else
    echo "No /tmp/CLAUDE.md found in image"
fi

# Handle SBT repositories file from ConfigMap mount
if [ -f /home/devuser/.sbt/repositories ]; then
    # Check if it's a mount point (ConfigMap)
    if mountpoint -q /home/devuser/.sbt/repositories 2>/dev/null || [ ! -w /home/devuser/.sbt/repositories ]; then
        echo "Found mounted .sbt/repositories file, creating writable copy..."
        # Copy to a different location
        cp /home/devuser/.sbt/repositories /home/devuser/.sbt/repositories.writable
        # Update the SBT_OPTS to use the writable copy
        export SBT_OPTS="-Dsbt.override.build.repos=true -Dsbt.repository.config=/home/devuser/.sbt/repositories.writable"
    fi
fi

# Ensure the devuser owns their directories
# Use || true to prevent script from exiting on chown errors for read-only mounts
chown -R devuser:devuser /home/devuser/.claude 2>/dev/null || true
chown -R devuser:devuser /home/devuser/workspace 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.config/claude-code 2>/dev/null || true
chown -R devuser:devuser /home/devuser/.local 2>/dev/null || true
# Skip chown for directories that might be mounted from ConfigMaps
# These are typically mounted as read-only
if [ ! -f /home/devuser/.cargo/config.toml ]; then
    chown -R devuser:devuser /home/devuser/.cargo 2>/dev/null || true
fi
if [ ! -f /home/devuser/.m2/settings.xml ]; then
    chown -R devuser:devuser /home/devuser/.m2 2>/dev/null || true
fi
# Always ensure SBT directories are owned by devuser
chown -R devuser:devuser /home/devuser/.sbt 2>/dev/null || true
if [ ! -f /home/devuser/.gradle/gradle.properties ]; then
    chown -R devuser:devuser /home/devuser/.gradle 2>/dev/null || true
fi

# Check if cargo config is properly mounted
if [ -f /home/devuser/.cargo/config.toml ]; then
    echo "Cargo config detected at /home/devuser/.cargo/config.toml"
fi

# Function to add line to file if not already present
add_if_not_exists() {
    local line="$1"
    local file="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Configure .bashrc for devuser (avoiding duplicates)
BASHRC="/home/devuser/.bashrc"
touch "$BASHRC"

# Add user's local bin to PATH
add_if_not_exists 'export PATH="$HOME/.local/bin:$PATH"' "$BASHRC"

# Add npm paths if npm is available
if command -v npm &> /dev/null; then
    add_if_not_exists 'export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"' "$BASHRC"
    add_if_not_exists 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"' "$BASHRC"
fi

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

# Add Rust/Cargo specific paths if installed
if [ -d /opt/rust ] && ! grep -q "Rust/Cargo paths" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# Rust/Cargo paths
export PATH="/opt/rust/bin:$PATH"
export RUSTUP_HOME="/opt/rust"
export CARGO_HOME="$HOME/.cargo"
EOF
fi

# Copy .condarc to devuser's home if conda is installed and .condarc exists
if [ -f /opt/conda/bin/conda ] && [ -f /root/.condarc ] && [ ! -f /home/devuser/.condarc ]; then
    cp /root/.condarc /home/devuser/.condarc
    chown devuser:devuser /home/devuser/.condarc
fi

# Configure bundler for devuser if Ruby is installed
if command -v ruby &> /dev/null && command -v bundle &> /dev/null; then
    # Create .bundle directory for bundler config
    mkdir -p /home/devuser/.bundle
    
    # Configure bundler to install gems to user's home directory
    cat > /home/devuser/.bundle/config << 'EOF'
---
BUNDLE_PATH: "/home/devuser/.bundle"
BUNDLE_BIN: "/home/devuser/.local/bin"
EOF
    
    # Ensure proper ownership
    chown -R devuser:devuser /home/devuser/.bundle
    
    # Add gem bin paths to .bashrc if not already present
    if ! grep -q "Ruby gem paths" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'

# Ruby gem paths
export GEM_HOME="$HOME/.bundle"
export PATH="$HOME/.local/bin:$HOME/.bundle/bin:$PATH"
EOF
    fi
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
        # Count installed tools only in the "Installed Development Environment" section
        TOOL_COUNT=$(sed -n '/## Installed Development Environment/,/^##[^#]/p' ~/.claude/CLAUDE.md 2>/dev/null | grep -E "^- " | wc -l)
        if [ $TOOL_COUNT -gt 0 ]; then
            echo "Environment: $TOOL_COUNT development tools installed"
            echo "  • cat ~/.claude/CLAUDE.md - View full configuration & guidelines"
            echo ""
        fi
    else
        # Count installed tools by checking common commands
        TOOL_COUNT=0
        for cmd in node python3 java rustc go ruby php; do
            command -v $cmd &> /dev/null && ((TOOL_COUNT++))
        done
        if [ $TOOL_COUNT -gt 0 ]; then
            echo "Environment: $TOOL_COUNT+ development tools installed"
            echo ""
        fi
    fi
fi
EOF
fi

# Verify installed components (only if expected)
if command -v claude &> /dev/null 2>&1; then
    echo "Claude Code is available at: $(which claude)"
fi

if command -v node &> /dev/null 2>&1; then
    echo "Node.js is available at: $(which node)"
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
        # Preserve environment variables that are important for proxies
        exec su - devuser -c "export PIP_INDEX_URL='$PIP_INDEX_URL' && \
                             export PIP_TRUSTED_HOST='$PIP_TRUSTED_HOST' && \
                             export NPM_CONFIG_REGISTRY='$NPM_CONFIG_REGISTRY' && \
                             export GOPROXY='$GOPROXY' && \
                             export CARGO_REGISTRIES_CRATES_IO_PROTOCOL='$CARGO_REGISTRIES_CRATES_IO_PROTOCOL' && \
                             export CARGO_HTTP_CHECK_REVOKE='$CARGO_HTTP_CHECK_REVOKE' && \
                             export CARGO_NET_GIT_FETCH_WITH_CLI='$CARGO_NET_GIT_FETCH_WITH_CLI' && \
                             export NO_PROXY='$NO_PROXY' && \
                             export no_proxy='$no_proxy' && \
                             export SBT_OPTS='${SBT_OPTS:-"-Dsbt.override.build.repos=true -Dsbt.repository.config=/home/devuser/.sbt/repositories"}' && \
                             $*"
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
