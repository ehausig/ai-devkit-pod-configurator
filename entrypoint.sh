#!/bin/bash
set -e

# Ensure PATH includes npm global binaries
export PATH="$PATH:/usr/local/bin:/usr/lib/node_modules/.bin"

# Source all profile scripts to load language paths
if [ -d /etc/profile.d ]; then
    for i in /etc/profile.d/*.sh; do
        if [ -r $i ]; then
            . $i
        fi
    done
fi

# Create config directory if it doesn't exist
CONFIG_DIR="/home/claude/.config/claude-code"
mkdir -p "$CONFIG_DIR"

# Create .local/bin directory for user pip installs
mkdir -p /home/claude/.local/bin

# Create .npm-global directory for user npm installs
mkdir -p /home/claude/.npm-global

# Create .cargo directory for Rust/Cargo if it doesn't exist
mkdir -p /home/claude/.cargo

# Create .m2 directory for Maven if it doesn't exist
mkdir -p /home/claude/.m2

# Create .sbt directory for SBT if it doesn't exist
mkdir -p /home/claude/.sbt

# Create .gradle directory for Gradle if it doesn't exist
mkdir -p /home/claude/.gradle

# Create .claude directory for global Claude configuration
mkdir -p /home/claude/.claude

# Copy CLAUDE.md to .claude folder if it exists in the image but not in the mounted volume
echo "Checking for CLAUDE.md..."
if [ -f /tmp/CLAUDE.md ]; then
    echo "Found /tmp/CLAUDE.md"
    if [ ! -f /home/claude/.claude/CLAUDE.md ]; then
        echo "Copying CLAUDE.md to .claude folder..."
        cp /tmp/CLAUDE.md /home/claude/.claude/CLAUDE.md
        echo "CLAUDE.md copied successfully to /home/claude/.claude/"
    else
        echo "CLAUDE.md already exists in .claude folder"
    fi
else
    echo "No /tmp/CLAUDE.md found in image"
fi

# Ensure the claude user owns their directories
# Use || true to prevent script from exiting on chown errors for read-only mounts
chown -R claude:claude /home/claude/.claude 2>/dev/null || true
chown -R claude:claude /home/claude/workspace 2>/dev/null || true
chown -R claude:claude /home/claude/.config/claude-code 2>/dev/null || true
chown -R claude:claude /home/claude/.local 2>/dev/null || true
# Skip chown for directories that might be mounted from ConfigMaps
# These are typically mounted as read-only
if [ ! -f /home/claude/.cargo/config.toml ]; then
    chown -R claude:claude /home/claude/.cargo 2>/dev/null || true
fi
if [ ! -f /home/claude/.m2/settings.xml ]; then
    chown -R claude:claude /home/claude/.m2 2>/dev/null || true
fi
if [ ! -f /home/claude/.sbt/repositories ]; then
    chown -R claude:claude /home/claude/.sbt 2>/dev/null || true
fi
if [ ! -f /home/claude/.gradle/gradle.properties ]; then
    chown -R claude:claude /home/claude/.gradle 2>/dev/null || true
fi

# Check if cargo config is properly mounted
if [ -f /home/claude/.cargo/config.toml ]; then
    echo "Cargo config detected at /home/claude/.cargo/config.toml"
fi

# Function to add line to file if not already present
add_if_not_exists() {
    local line="$1"
    local file="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Configure .bashrc for claude user (avoiding duplicates)
BASHRC="/home/claude/.bashrc"
touch "$BASHRC"

# Add user's local bin to PATH
add_if_not_exists 'export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"' "$BASHRC"
add_if_not_exists 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"' "$BASHRC"

# Add terminal configuration for better CLI support
add_if_not_exists 'export TERM=xterm-256color' "$BASHRC"
add_if_not_exists 'export FORCE_COLOR=1' "$BASHRC"
add_if_not_exists 'export CI=false' "$BASHRC"

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

# Copy .condarc to claude's home if conda is installed and .condarc exists
if [ -f /opt/conda/bin/conda ] && [ -f /root/.condarc ] && [ ! -f /home/claude/.condarc ]; then
    cp /root/.condarc /home/claude/.condarc
    chown claude:claude /home/claude/.condarc
fi

# Configure bundler for claude user if Ruby is installed
if command -v ruby &> /dev/null && command -v bundle &> /dev/null; then
    # Create .bundle directory for bundler config
    mkdir -p /home/claude/.bundle
    
    # Configure bundler to install gems to user's home directory
    cat > /home/claude/.bundle/config << 'EOF'
---
BUNDLE_PATH: "/home/claude/.bundle"
BUNDLE_BIN: "/home/claude/.local/bin"
EOF
    
    # Ensure proper ownership
    chown -R claude:claude /home/claude/.bundle
    
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
chown claude:claude "$BASHRC"

# Add welcome message to .bashrc
if ! grep -q "Claude Code Welcome" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# Claude Code Welcome Message
if [ -n "$PS1" ] && [ -z "$CLAUDE_WELCOME_SHOWN" ]; then
    export CLAUDE_WELCOME_SHOWN=1
    echo ""
    echo "Welcome to Claude Code Development Kit! 🚀"
    echo ""
    echo "Quick Start:"
    echo "  • cd workspace      - Navigate to your workspace"
    echo "  • claude           - Start Claude Code"
    echo "  • claude --help    - Show available commands"
    echo ""
    if [ -f ~/.claude/CLAUDE.md ]; then
        # Count installed tools
        TOOL_COUNT=$(grep -E "^- " ~/.claude/CLAUDE.md 2>/dev/null | wc -l)
        if [ $TOOL_COUNT -gt 5 ]; then
            echo "Environment: $TOOL_COUNT development tools installed"
            echo "  • cat ~/.claude/CLAUDE.md - View installed tools & guidelines"
            echo ""
        fi
    fi
fi
EOF
fi

# Verify Claude Code is available
if ! command -v claude &> /dev/null; then
    echo "ERROR: Claude Code command not found in PATH"
    echo "PATH: $PATH"
    echo "Installed npm packages:"
    npm list -g --depth=0
    exit 1
fi

echo "Claude Code is available at: $(which claude)"

# Switch to claude user and execute the command
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, preparing to switch to claude user..."
    # If no command specified, sleep indefinitely
    if [ $# -eq 0 ]; then
        echo "No command specified, running sleep infinity to keep container alive..."
        exec sleep infinity
    else
        echo "Switching to claude user to run: $*"
        # Preserve environment variables that are important for proxies
        exec su - claude -c "export PIP_INDEX_URL='$PIP_INDEX_URL' && \
                             export PIP_TRUSTED_HOST='$PIP_TRUSTED_HOST' && \
                             export NPM_CONFIG_REGISTRY='$NPM_CONFIG_REGISTRY' && \
                             export GOPROXY='$GOPROXY' && \
                             export CARGO_REGISTRIES_CRATES_IO_PROTOCOL='$CARGO_REGISTRIES_CRATES_IO_PROTOCOL' && \
                             export CARGO_HTTP_CHECK_REVOKE='$CARGO_HTTP_CHECK_REVOKE' && \
                             export CARGO_NET_GIT_FETCH_WITH_CLI='$CARGO_NET_GIT_FETCH_WITH_CLI' && \
                             export NO_PROXY='$NO_PROXY' && \
                             export no_proxy='$no_proxy' && \
                             export SBT_OPTS='-Dsbt.override.build.repos=true -Dsbt.repository.config=/home/claude/.sbt/repositories' && \
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
