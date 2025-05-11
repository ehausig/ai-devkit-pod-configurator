FROM ubuntu:22.04

# Setup environment for arm64 architecture
ARG TARGETARCH=arm64

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies (excluding Node.js)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    git \
    python3 \
    python3-pip \
    vim \
    jq \
    wget \
    bash-completion \
    --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Remove any existing Node.js installation
RUN apt-get update && \
    apt-get remove -y nodejs npm libnode-dev && \
    apt-get autoremove -y && \
    rm -rf /usr/local/lib/node_modules && \
    rm -rf /usr/local/bin/node* && \
    rm -rf /usr/local/bin/npm*

# Install the latest Node.js (Claude Code requires Node.js 18+)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Verify Claude Code installation
RUN which claude || (echo "Claude Code installation failed" && exit 1)

# Create a directory for user configuration
RUN mkdir -p /root/.config/claude-code

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create a non-root user to run Claude Code (optional, based on security requirements)
RUN useradd -ms /bin/bash claude
RUN mkdir -p /home/claude/.config/claude-code
RUN chown -R claude:claude /home/claude/

# Set up volume mount points for persistence
VOLUME ["/home/claude/.config/claude-code", "/home/claude/workspace"]

# Switch to the claude user for runtime (but not for entrypoint)
USER claude
WORKDIR /home/claude

# Switch back to root for the entrypoint
USER root
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
