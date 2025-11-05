#!/bin/bash
# configure-wash.sh
# Interactive script to configure wash CLI for remote wasmCloud connections

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

WASH_DIR="$HOME/.wash"
WASH_CONFIG="$WASH_DIR/config.json"

# Display header
show_header() {
    echo -e "${CYAN}"
    echo "================================================================================"
    echo "                    wasmCloud Connection Configuration                         "
    echo "================================================================================"
    echo -e "${NC}"
}

# Display help
show_help() {
    show_header
    echo "This script helps you configure wash CLI to connect to wasmCloud hosts."
    echo ""
    echo "Usage: configure-wash.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --auto              Auto-detect host environment (recommended)"
    echo "  --host-nats         Connect to NATS on host machine"
    echo "  --remote            Configure remote wasmCloud connection"
    echo "  --local             Use local wasmCloud (default)"
    echo "  --show-config       Show current configuration"
    echo ""
    echo "Interactive mode (no options) will guide you through configuration."
    echo ""
}

# Show current configuration
show_config() {
    if [[ -f "$WASH_CONFIG" ]]; then
        echo -e "${CYAN}Current wash configuration:${NC}"
        cat "$WASH_CONFIG"
    else
        echo -e "${YELLOW}No configuration file found at $WASH_CONFIG${NC}"
    fi
}

# Auto-detect environment
auto_detect() {
    show_header
    echo -e "${CYAN}Auto-detecting environment...${NC}"
    echo ""

    # Check if already configured
    if [[ -f "$WASH_CONFIG" ]]; then
        echo -e "${YELLOW}⚠ Existing wash configuration found${NC}"
        read -p "Overwrite existing configuration? [y/N]: " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Keeping existing configuration"
            return 0
        fi
        mv "$WASH_CONFIG" "${WASH_CONFIG}.backup.$(date +%s)"
        echo -e "${BLUE}  Backed up existing config${NC}"
    fi

    # Try to detect host NATS
    echo -e "${BLUE}Checking for NATS on host...${NC}"

    # Common NATS ports and hosts
    local nats_hosts=(
        "host.docker.internal:4222"
        "172.17.0.1:4222"
        "10.0.2.2:4222"
    )

    for nats_host in "${nats_hosts[@]}"; do
        if timeout 2 bash -c "echo > /dev/tcp/${nats_host%%:*}/${nats_host##*:}" 2>/dev/null; then
            echo -e "${GREEN}✓ Found NATS at $nats_host${NC}"
            configure_host_nats "$nats_host"
            return 0
        fi
    done

    echo -e "${YELLOW}⚠ Could not auto-detect NATS server${NC}"
    echo ""
    echo "Would you like to:"
    echo "  1) Manually enter NATS connection details"
    echo "  2) Use local wasmCloud (wash up)"
    echo "  3) Exit"
    read -p "Enter choice [1-3]: " choice

    case $choice in
        1)
            manual_config
            ;;
        2)
            configure_local
            ;;
        3)
            echo "Exiting..."
            return 1
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return 1
            ;;
    esac
}

# Configure for host NATS
configure_host_nats() {
    local nats_url="${1:-host.docker.internal:4222}"

    echo -e "${YELLOW}Configuring for host NATS at $nats_url...${NC}"

    mkdir -p "$WASH_DIR"

    cat > "$WASH_CONFIG" <<EOF
{
  "default": {
    "ctl_host": "nats://$nats_url",
    "rpc_host": "nats://$nats_url",
    "lattice": "default",
    "timeout_ms": 2000
  }
}
EOF

    chmod 600 "$WASH_CONFIG"

    echo -e "${GREEN}✓ Configuration created${NC}"
    echo -e "${BLUE}  NATS URL: nats://$nats_url${NC}"
    echo -e "${BLUE}  Lattice: default${NC}"
}

# Configure for local wasmCloud
configure_local() {
    echo -e "${YELLOW}Configuring for local wasmCloud...${NC}"

    mkdir -p "$WASH_DIR"

    cat > "$WASH_CONFIG" <<EOF
{
  "default": {
    "ctl_host": "nats://127.0.0.1:4222",
    "rpc_host": "nats://127.0.0.1:4222",
    "lattice": "default",
    "timeout_ms": 2000
  }
}
EOF

    chmod 600 "$WASH_CONFIG"

    echo -e "${GREEN}✓ Local configuration created${NC}"
    echo -e "${BLUE}  Use 'wash up' to start a local wasmCloud host${NC}"
}

# Manual configuration
manual_config() {
    show_header
    echo -e "${CYAN}Manual wasmCloud Configuration${NC}"
    echo ""

    echo "Enter NATS connection details for your wasmCloud host:"
    echo ""

    # Get NATS host
    read -p "NATS host [host.docker.internal]: " nats_host
    nats_host=${nats_host:-host.docker.internal}

    # Get NATS port
    read -p "NATS port [4222]: " nats_port
    nats_port=${nats_port:-4222}

    # Get lattice name
    read -p "Lattice name [default]: " lattice
    lattice=${lattice:-default}

    # Optional: Get credentials
    echo ""
    echo "Does your NATS server require authentication?"
    read -p "Use credentials? [y/N]: " use_creds

    local nats_url="nats://${nats_host}:${nats_port}"

    if [[ "$use_creds" =~ ^[Yy]$ ]]; then
        read -p "NATS user: " nats_user
        read -sp "NATS password: " nats_pass
        echo ""

        if [[ -n "$nats_user" ]] && [[ -n "$nats_pass" ]]; then
            nats_url="nats://${nats_user}:${nats_pass}@${nats_host}:${nats_port}"
        fi
    fi

    mkdir -p "$WASH_DIR"

    cat > "$WASH_CONFIG" <<EOF
{
  "default": {
    "ctl_host": "$nats_url",
    "rpc_host": "$nats_url",
    "lattice": "$lattice",
    "timeout_ms": 2000
  }
}
EOF

    chmod 600 "$WASH_CONFIG"

    echo ""
    echo -e "${GREEN}✓ Configuration created successfully${NC}"
    echo -e "${BLUE}  NATS: ${nats_host}:${nats_port}${NC}"
    echo -e "${BLUE}  Lattice: $lattice${NC}"
}

# Test connection
test_connection() {
    if [[ ! -f "$WASH_CONFIG" ]]; then
        echo -e "${YELLOW}No configuration file found${NC}"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Testing connection to wasmCloud...${NC}"

    # Try to connect using wash
    if timeout 5 wash get hosts &>/dev/null; then
        echo -e "${GREEN}✓ Successfully connected to wasmCloud${NC}"
        echo ""
        echo -e "${CYAN}Available hosts:${NC}"
        wash get hosts
        echo ""
        echo -e "${CYAN}Quick start:${NC}"
        echo "  wash app list              # List applications"
        echo "  wash get hosts             # List hosts"
        echo "  wash get inventory <host>  # Show host inventory"
        return 0
    else
        echo -e "${RED}✗ Failed to connect to wasmCloud${NC}"
        echo -e "${YELLOW}  Check your configuration and wasmCloud host${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  - Ensure wasmCloud is running (on host or remote)"
        echo "  - Check NATS server is accessible"
        echo "  - Verify network connectivity"
        echo "  - For host access, ensure port 4222 is accessible"
        echo ""
        echo "To start a local wasmCloud host:"
        echo "  wash up"
        return 1
    fi
}

# Interactive mode
interactive_mode() {
    show_header

    echo "Choose a configuration method:"
    echo ""
    echo "  1) Auto-detect (recommended) - Automatically find and configure"
    echo "  2) Host NATS - Connect to NATS on host machine"
    echo "  3) Manual configuration - Enter connection details"
    echo "  4) Local wasmCloud - Use local instance (wash up)"
    echo "  5) Show current configuration"
    echo "  6) Exit"
    echo ""
    read -p "Enter choice [1-6]: " choice

    case $choice in
        1)
            auto_detect && test_connection
            ;;
        2)
            configure_host_nats && test_connection
            ;;
        3)
            manual_config && test_connection
            ;;
        4)
            configure_local
            echo ""
            echo "Configuration created. Start wasmCloud with:"
            echo "  wash up"
            ;;
        5)
            show_config
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
}

# Main script logic
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --auto)
            auto_detect && test_connection
            ;;
        --host-nats)
            configure_host_nats && test_connection
            ;;
        --remote)
            manual_config && test_connection
            ;;
        --local)
            configure_local
            ;;
        --show-config)
            show_config
            ;;
        "")
            interactive_mode
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
