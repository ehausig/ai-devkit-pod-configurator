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
chown -R claude:claude "$CONFIG_DIR"

# Ensure the claude user owns their workspace
chown -R claude:claude /home/claude/workspace

# Fix permissions for pip if it exists
if [ -d "/home/claude/.local" ]; then
    chown -R claude:claude /home/claude/.local
fi

# Create .local/bin directory for user pip installs
mkdir -p /home/claude/.local/bin
chown -R claude:claude /home/claude/.local

# Create .cargo directory for Rust/Cargo if it doesn't exist
if [ ! -d /home/claude/.cargo ]; then
    echo "Creating .cargo directory..."
    mkdir -p /home/claude/.cargo
fi

# Check if cargo config is properly mounted
if [ -f /home/claude/.cargo/config.toml ]; then
    echo "Cargo config detected at /home/claude/.cargo/config.toml"
    echo "Contents:"
    cat /home/claude/.cargo/config.toml
    # Fix ownership of the entire .cargo directory and its contents
    chown -R claude:claude /home/claude/.cargo
    echo "Fixed ownership of .cargo directory"
else
    echo "WARNING: No cargo config found at /home/claude/.cargo/config.toml"
fi

# Add user's local bin to PATH for claude user
echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/claude/.bashrc

# Source all profile.d scripts for claude user
echo '# Source system-wide profile scripts' >> /home/claude/.bashrc
echo 'if [ -d /etc/profile.d ]; then' >> /home/claude/.bashrc
echo '    for i in /etc/profile.d/*.sh; do' >> /home/claude/.bashrc
echo '        if [ -r $i ]; then' >> /home/claude/.bashrc
echo '            . $i' >> /home/claude/.bashrc
echo '        fi' >> /home/claude/.bashrc
echo '    done' >> /home/claude/.bashrc
echo 'fi' >> /home/claude/.bashrc

# Add Rust/Cargo specific paths if installed
if [ -d /opt/rust ]; then
    echo '# Rust/Cargo paths' >> /home/claude/.bashrc
    echo 'export PATH="/opt/rust/bin:$PATH"' >> /home/claude/.bashrc
    echo 'export RUSTUP_HOME="/opt/rust"' >> /home/claude/.bashrc
    echo 'export CARGO_HOME="$HOME/.cargo"' >> /home/claude/.bashrc
fi

# Verify Claude Code is available
if ! command -v claude &> /dev/null; then
    echo "ERROR: Claude Code command not found in PATH"
    echo "PATH: $PATH"
    echo "Installed npm packages:"
    npm list -g --depth=0
    exit 1
fi

# Switch to claude user and execute the command
if [ "$(id -u)" = "0" ]; then
    echo "Switching to claude user..."
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
                         $*"
else
    exec "$@"
fi
