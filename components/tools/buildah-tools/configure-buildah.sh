#!/bin/bash
# configure-buildah.sh
# Interactive script to configure container registries for buildah/podman

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

CONTAINERS_DIR="$HOME/.config/containers"
REGISTRIES_CONF="$CONTAINERS_DIR/registries.conf"
AUTH_FILE="$CONTAINERS_DIR/auth.json"
CERT_DIR="$HOME/.config/containers/certs.d"

# Display header
show_header() {
    echo -e "${CYAN}"
    echo "================================================================================"
    echo "                    Container Registry Configuration                           "
    echo "================================================================================"
    echo -e "${NC}"
}

# Display help
show_help() {
    show_header
    echo "This script helps you configure container registries for buildah and podman."
    echo ""
    echo "Usage: configure-buildah.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --add-registry      Add a new registry"
    echo "  --list              List configured registries"
    echo "  --test <registry>   Test connection to a registry"
    echo "  --show-config       Show current configuration"
    echo ""
    echo "Interactive mode (no options) will guide you through configuration."
    echo ""
}

# Show current configuration
show_config() {
    echo -e "${CYAN}Current registries configuration:${NC}"
    if [[ -f "$REGISTRIES_CONF" ]]; then
        cat "$REGISTRIES_CONF"
    else
        echo -e "${YELLOW}No configuration file found at $REGISTRIES_CONF${NC}"
    fi
    echo ""

    echo -e "${CYAN}Configured authentication:${NC}"
    if [[ -f "$AUTH_FILE" ]]; then
        echo "Authentication file exists at $AUTH_FILE"
        if command -v jq &>/dev/null; then
            echo "Registries with auth:"
            jq -r '.auths | keys[]' "$AUTH_FILE" 2>/dev/null || echo "Unable to parse auth file"
        fi
    else
        echo -e "${YELLOW}No authentication configured${NC}"
    fi
}

# List configured registries
list_registries() {
    echo -e "${CYAN}Configured registries:${NC}"
    if [[ -f "$REGISTRIES_CONF" ]]; then
        grep -E "^\s*location\s*=" "$REGISTRIES_CONF" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/  - \1/' || echo "No registries configured"
    else
        echo -e "${YELLOW}No registries configured${NC}"
    fi
}

# Test registry connection
test_registry() {
    local registry="$1"

    if [[ -z "$registry" ]]; then
        echo -e "${RED}Error: No registry specified${NC}"
        return 1
    fi

    echo -e "${YELLOW}Testing connection to $registry...${NC}"

    # Try to inspect a common image or just test connectivity
    if skopeo inspect --tls-verify=false "docker://${registry}/hello-world:latest" &>/dev/null; then
        echo -e "${GREEN}✓ Successfully connected to $registry${NC}"
        return 0
    elif timeout 5 bash -c "echo > /dev/tcp/${registry%%:*}/${registry##*:}" 2>/dev/null; then
        echo -e "${GREEN}✓ Registry is reachable at $registry${NC}"
        echo -e "${YELLOW}  Note: Could not pull test image, but network connectivity confirmed${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to connect to $registry${NC}"
        echo -e "${YELLOW}  Check: Network connectivity, registry URL, and TLS configuration${NC}"
        return 1
    fi
}

# Add a registry
add_registry() {
    show_header
    echo -e "${CYAN}Add Container Registry${NC}"
    echo ""

    # Get registry URL
    echo "Enter the registry URL (e.g., registry.example.com:443):"
    read -p "Registry URL: " registry_url

    if [[ -z "$registry_url" ]]; then
        echo -e "${RED}Error: Registry URL cannot be empty${NC}"
        return 1
    fi

    # Ask about TLS
    echo ""
    echo "Does this registry use HTTPS/TLS?"
    read -p "Use TLS? [Y/n]: " use_tls
    use_tls=${use_tls:-y}

    # Ask about insecure registry
    insecure="false"
    if [[ "$use_tls" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Skip TLS certificate verification? (insecure, not recommended)"
        read -p "Skip TLS verification? [y/N]: " skip_verify
        if [[ "$skip_verify" =~ ^[Yy]$ ]]; then
            insecure="true"
        fi
    else
        insecure="true"
    fi

    # Ask about custom CA certificate
    if [[ "$use_tls" =~ ^[Yy]$ ]] && [[ "$insecure" != "true" ]]; then
        echo ""
        echo "Does this registry use a custom CA certificate?"
        read -p "Provide custom CA certificate? [y/N]: " use_custom_ca

        if [[ "$use_custom_ca" =~ ^[Yy]$ ]]; then
            install_ca_cert "$registry_url"
        fi
    fi

    # Ask about authentication
    echo ""
    echo "Does this registry require authentication?"
    read -p "Configure authentication? [y/N]: " needs_auth

    if [[ "$needs_auth" =~ ^[Yy]$ ]]; then
        configure_auth "$registry_url"
    fi

    # Add registry to registries.conf
    echo ""
    echo -e "${YELLOW}Adding registry to configuration...${NC}"

    # Create or update registries.conf
    mkdir -p "$CONTAINERS_DIR"

    # Check if registry already exists
    if grep -q "location = \"$registry_url\"" "$REGISTRIES_CONF" 2>/dev/null; then
        echo -e "${YELLOW}Registry already configured, updating...${NC}"
        # Remove existing entry (simple approach - might need improvement)
        sed -i "/\[\[registry\]\]/,/^$/d" "$REGISTRIES_CONF" 2>/dev/null || true
    fi

    # Append new registry configuration
    cat >> "$REGISTRIES_CONF" << EOF

[[registry]]
location = "$registry_url"
insecure = $insecure
EOF

    echo -e "${GREEN}✓ Registry added to configuration${NC}"

    # Test the registry
    echo ""
    test_registry "$registry_url"
}

# Install CA certificate for a registry
install_ca_cert() {
    local registry_url="$1"

    echo ""
    echo -e "${CYAN}Installing Custom CA Certificate${NC}"
    echo ""
    echo "Please paste the CA certificate (PEM format)."
    echo "Press Ctrl+D when done:"
    echo ""

    # Read certificate from stdin
    local cert_content=""
    while IFS= read -r line; do
        cert_content+="$line"$'\n'
    done

    if [[ -z "$cert_content" ]]; then
        echo -e "${YELLOW}No certificate provided, skipping...${NC}"
        return 0
    fi

    # Create cert directory for registry
    local cert_dir="$CERT_DIR/$registry_url"
    mkdir -p "$cert_dir"

    # Save certificate
    echo "$cert_content" > "$cert_dir/ca.crt"
    chmod 644 "$cert_dir/ca.crt"

    echo -e "${GREEN}✓ CA certificate installed for $registry_url${NC}"
}

# Configure authentication for a registry
configure_auth() {
    local registry_url="$1"

    echo ""
    echo -e "${CYAN}Configure Authentication${NC}"
    echo ""

    read -p "Username: " username
    read -sp "Password: " password
    echo ""

    if [[ -z "$username" ]] || [[ -z "$password" ]]; then
        echo -e "${YELLOW}Username or password empty, skipping authentication...${NC}"
        return 0
    fi

    # Use podman login to configure authentication
    echo "$password" | podman login --username "$username" --password-stdin "$registry_url" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Authentication configured for $registry_url${NC}"
    else
        echo -e "${RED}✗ Failed to configure authentication${NC}"
        echo -e "${YELLOW}  You can manually configure credentials in $AUTH_FILE${NC}"
    fi
}

# Interactive mode
interactive_mode() {
    show_header

    echo "Choose an action:"
    echo ""
    echo "  1) Add a new registry"
    echo "  2) List configured registries"
    echo "  3) Test registry connection"
    echo "  4) Show configuration files"
    echo "  5) Exit"
    echo ""
    read -p "Enter choice [1-5]: " choice

    case $choice in
        1)
            add_registry
            ;;
        2)
            list_registries
            ;;
        3)
            echo ""
            read -p "Enter registry URL to test: " test_reg
            test_registry "$test_reg"
            ;;
        4)
            show_config
            ;;
        5)
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
        --add-registry)
            add_registry
            ;;
        --list)
            list_registries
            ;;
        --test)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: --test requires a registry URL${NC}"
                exit 1
            fi
            test_registry "$2"
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
