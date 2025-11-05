#!/bin/bash
# configure-kubeconfig.sh
# Interactive script to configure Kubernetes cluster access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

KUBE_DIR="$HOME/.kube"
KUBE_CONFIG="$KUBE_DIR/config"

# Display header
show_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Kubernetes Cluster Configuration                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Display help
show_help() {
    show_header
    echo "This script helps you configure access to Kubernetes clusters."
    echo ""
    echo "Usage: configure-kubeconfig.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --detect-k3s        Auto-detect and configure K3s from host"
    echo "  --manual            Manually configure cluster access"
    echo "  --show-contexts     Show current contexts"
    echo "  --current-context   Show current active context"
    echo ""
    echo "Interactive mode (no options) will guide you through the configuration."
    echo ""
}

# Check if K3s config exists on host (assuming volume mount or shared path)
detect_k3s() {
    echo -e "${YELLOW}Checking for K3s configuration...${NC}"

    # Common K3s config locations that might be volume-mounted
    local k3s_paths=(
        "/host/etc/rancher/k3s/k3s.yaml"
        "/etc/rancher/k3s/k3s.yaml"
        "/var/lib/rancher/k3s/server/cred/admin.kubeconfig"
    )

    for k3s_path in "${k3s_paths[@]}"; do
        if [[ -f "$k3s_path" ]]; then
            echo -e "${GREEN}✓ Found K3s configuration at: $k3s_path${NC}"

            # Create .kube directory if it doesn't exist
            mkdir -p "$KUBE_DIR"

            # Copy and modify the config
            cp "$k3s_path" "$KUBE_CONFIG"

            # Replace server address (typically 127.0.0.1) with host.docker.internal
            sed -i 's|https://127.0.0.1:6443|https://host.docker.internal:6443|g' "$KUBE_CONFIG"
            sed -i 's|https://localhost:6443|https://host.docker.internal:6443|g' "$KUBE_CONFIG"

            chmod 600 "$KUBE_CONFIG"

            echo -e "${GREEN}✓ K3s configuration copied and configured${NC}"
            echo -e "${BLUE}  Server updated to use: host.docker.internal:6443${NC}"

            return 0
        fi
    done

    echo -e "${YELLOW}⚠ K3s configuration not found${NC}"
    echo -e "${YELLOW}  To use K3s, ensure /etc/rancher/k3s/k3s.yaml is volume-mounted${NC}"
    return 1
}

# Show current contexts
show_contexts() {
    if [[ ! -f "$KUBE_CONFIG" ]]; then
        echo -e "${YELLOW}No kubeconfig file found at $KUBE_CONFIG${NC}"
        return 1
    fi

    echo -e "${CYAN}Current Kubernetes contexts:${NC}"
    kubectl config get-contexts
}

# Show current context
show_current_context() {
    if [[ ! -f "$KUBE_CONFIG" ]]; then
        echo -e "${YELLOW}No kubeconfig file found at $KUBE_CONFIG${NC}"
        return 1
    fi

    local current=$(kubectl config current-context 2>/dev/null || echo "none")
    echo -e "${CYAN}Current context: ${GREEN}$current${NC}"
}

# Manual configuration
manual_config() {
    show_header
    echo -e "${CYAN}Manual Cluster Configuration${NC}"
    echo ""

    echo "Please enter the following information for your Kubernetes cluster:"
    echo ""

    # Get cluster name
    read -p "Cluster name: " cluster_name
    if [[ -z "$cluster_name" ]]; then
        echo -e "${RED}Error: Cluster name is required${NC}"
        return 1
    fi

    # Get server URL
    read -p "Server URL (e.g., https://cluster.example.com:6443): " server_url
    if [[ -z "$server_url" ]]; then
        echo -e "${RED}Error: Server URL is required${NC}"
        return 1
    fi

    # Choose authentication method
    echo ""
    echo "Select authentication method:"
    echo "  1) Certificate (certificate-authority-data, client-certificate-data, client-key-data)"
    echo "  2) Token (bearer token)"
    echo "  3) Username/Password"
    read -p "Enter choice [1-3]: " auth_choice

    mkdir -p "$KUBE_DIR"

    case $auth_choice in
        1)
            echo ""
            echo "Enter the base64-encoded certificate data:"
            read -p "Certificate Authority Data: " ca_data
            read -p "Client Certificate Data: " cert_data
            read -p "Client Key Data: " key_data

            # Create config with certificate auth
            cat > "$KUBE_CONFIG" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $ca_data
    server: $server_url
  name: $cluster_name
contexts:
- context:
    cluster: $cluster_name
    user: ${cluster_name}-user
  name: $cluster_name
current-context: $cluster_name
users:
- name: ${cluster_name}-user
  user:
    client-certificate-data: $cert_data
    client-key-data: $key_data
EOF
            ;;
        2)
            echo ""
            read -p "Bearer Token: " token

            # Create config with token auth
            cat > "$KUBE_CONFIG" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $server_url
  name: $cluster_name
contexts:
- context:
    cluster: $cluster_name
    user: ${cluster_name}-user
  name: $cluster_name
current-context: $cluster_name
users:
- name: ${cluster_name}-user
  user:
    token: $token
EOF
            ;;
        3)
            echo ""
            read -p "Username: " username
            read -sp "Password: " password
            echo ""

            # Create config with basic auth
            cat > "$KUBE_CONFIG" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $server_url
  name: $cluster_name
contexts:
- context:
    cluster: $cluster_name
    user: ${cluster_name}-user
  name: $cluster_name
current-context: $cluster_name
users:
- name: ${cluster_name}-user
  user:
    username: $username
    password: $password
EOF
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return 1
            ;;
    esac

    chmod 600 "$KUBE_CONFIG"
    echo ""
    echo -e "${GREEN}✓ Kubeconfig created successfully${NC}"
}

# Test connection
test_connection() {
    if [[ ! -f "$KUBE_CONFIG" ]]; then
        echo -e "${YELLOW}No kubeconfig file found${NC}"
        return 1
    fi

    echo -e "${YELLOW}Testing connection to cluster...${NC}"

    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}✓ Successfully connected to cluster${NC}"
        kubectl cluster-info
        return 0
    else
        echo -e "${RED}✗ Failed to connect to cluster${NC}"
        echo -e "${YELLOW}  Check your configuration and network connectivity${NC}"
        return 1
    fi
}

# Interactive mode
interactive_mode() {
    show_header

    echo "Choose a configuration method:"
    echo ""
    echo "  1) Auto-detect K3s from host"
    echo "  2) Manual cluster configuration"
    echo "  3) Copy existing kubeconfig (paste content)"
    echo "  4) Show current contexts"
    echo "  5) Exit"
    echo ""
    read -p "Enter choice [1-5]: " choice

    case $choice in
        1)
            if detect_k3s; then
                test_connection
            else
                echo -e "${YELLOW}Would you like to try manual configuration instead? [y/N]${NC}"
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    manual_config && test_connection
                fi
            fi
            ;;
        2)
            manual_config && test_connection
            ;;
        3)
            mkdir -p "$KUBE_DIR"
            echo ""
            echo "Paste your kubeconfig content, then press Ctrl+D:"
            cat > "$KUBE_CONFIG"
            chmod 600 "$KUBE_CONFIG"
            echo -e "${GREEN}✓ Kubeconfig saved${NC}"
            test_connection
            ;;
        4)
            show_contexts
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
    # Parse arguments
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --detect-k3s)
            detect_k3s && test_connection
            ;;
        --manual)
            manual_config && test_connection
            ;;
        --show-contexts)
            show_contexts
            ;;
        --current-context)
            show_current_context
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
