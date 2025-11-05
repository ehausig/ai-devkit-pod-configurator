#!/bin/bash
# configure-kubeconfig.sh
# Interactive script to configure Kubernetes cluster access with auto-detection

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
    echo "  --auto              Auto-detect environment and configure (recommended)"
    echo "  --in-cluster        Configure for in-cluster access"
    echo "  --detect-k3s        Auto-detect and configure K3s from host"
    echo "  --manual            Manually configure cluster access"
    echo "  --show-contexts     Show current contexts"
    echo "  --current-context   Show current active context"
    echo ""
    echo "Interactive mode (no options) will guide you through the configuration."
    echo ""
}

# Detect if running inside a Kubernetes cluster
is_in_cluster() {
    # Check for Kubernetes service account
    if [[ -f "/var/run/secrets/kubernetes.io/serviceaccount/token" ]] && \
       [[ -f "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt" ]]; then
        return 0
    fi
    return 1
}

# Configure for in-cluster access
configure_in_cluster() {
    echo -e "${YELLOW}Configuring for in-cluster access...${NC}"

    local sa_token_path="/var/run/secrets/kubernetes.io/serviceaccount/token"
    local sa_ca_path="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    local sa_namespace_path="/var/run/secrets/kubernetes.io/serviceaccount/namespace"

    if [[ ! -f "$sa_token_path" ]] || [[ ! -f "$sa_ca_path" ]]; then
        echo -e "${RED}✗ Service account credentials not found${NC}"
        return 1
    fi

    local token=$(cat "$sa_token_path")
    local ca_data=$(base64 -w 0 "$sa_ca_path" 2>/dev/null || base64 "$sa_ca_path")
    local namespace=$(cat "$sa_namespace_path" 2>/dev/null || echo "default")

    # Try different server URLs in order of preference
    local server_urls=(
        "https://kubernetes.default.svc.cluster.local:443"
        "https://kubernetes.default.svc:443"
        "https://kubernetes.default:443"
        "https://10.43.0.1:443"
    )

    mkdir -p "$KUBE_DIR"

    # Create config with in-cluster credentials
    cat > "$KUBE_CONFIG" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $ca_data
    server: ${server_urls[0]}
  name: in-cluster
contexts:
- context:
    cluster: in-cluster
    namespace: $namespace
    user: in-cluster-user
  name: in-cluster
current-context: in-cluster
users:
- name: in-cluster-user
  user:
    token: $token
EOF

    chmod 600 "$KUBE_CONFIG"

    echo -e "${GREEN}✓ In-cluster configuration created${NC}"
    echo -e "${BLUE}  Server: ${server_urls[0]}${NC}"
    echo -e "${BLUE}  Namespace: $namespace${NC}"

    return 0
}

# Auto-detect environment and configure
auto_detect() {
    show_header
    echo -e "${CYAN}Auto-detecting environment...${NC}"
    echo ""

    # Check if already configured
    if [[ -f "$KUBE_CONFIG" ]]; then
        echo -e "${YELLOW}⚠ Existing kubeconfig found at $KUBE_CONFIG${NC}"
        read -p "Overwrite existing configuration? [y/N]: " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Keeping existing configuration"
            return 0
        fi
        mv "$KUBE_CONFIG" "${KUBE_CONFIG}.backup.$(date +%s)"
        echo -e "${BLUE}  Backed up existing config${NC}"
    fi

    # Priority 1: Check if running inside Kubernetes cluster
    if is_in_cluster; then
        echo -e "${GREEN}✓ Detected: Running inside Kubernetes cluster${NC}"
        echo ""
        if configure_in_cluster; then
            return 0
        else
            echo -e "${YELLOW}⚠ In-cluster configuration failed, trying other methods...${NC}"
        fi
    fi

    # Priority 2: Check for K3s configuration on host
    echo -e "${BLUE}Checking for K3s on host...${NC}"
    if detect_k3s_silent; then
        echo -e "${GREEN}✓ Detected: K3s configuration on host${NC}"
        echo ""

        # Determine the best server URL based on environment
        local server_url
        if [[ -n "${COLIMA_HOME}" ]] || [[ -n "${DOCKER_HOST}" ]]; then
            server_url="https://host.docker.internal:6443"
            echo -e "${BLUE}  Using Docker/Colima bridge: $server_url${NC}"
        else
            # Try to detect host IP
            local host_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
            if [[ -n "$host_ip" ]]; then
                server_url="https://$host_ip:6443"
                echo -e "${BLUE}  Using host IP: $server_url${NC}"
            else
                server_url="https://host.docker.internal:6443"
                echo -e "${BLUE}  Using default: $server_url${NC}"
            fi
        fi

        # Update the server URL in the copied config
        sed -i "s|https://127.0.0.1:6443|$server_url|g" "$KUBE_CONFIG"
        sed -i "s|https://localhost:6443|$server_url|g" "$KUBE_CONFIG"
        sed -i "s|https://.*:6443|$server_url|g" "$KUBE_CONFIG"

        echo -e "${GREEN}✓ K3s configuration applied${NC}"
        return 0
    fi

    # Priority 3: No auto-detection succeeded
    echo -e "${YELLOW}⚠ Could not auto-detect cluster configuration${NC}"
    echo ""
    echo "Manual configuration required. Please choose an option:"
    echo ""
    echo "  1) Manually enter cluster details"
    echo "  2) Paste existing kubeconfig"
    echo "  3) Exit"
    echo ""
    read -p "Enter choice [1-3]: " choice

    case $choice in
        1)
            manual_config
            ;;
        2)
            paste_config
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

# Silent version of detect_k3s (returns 0/1, minimal output)
detect_k3s_silent() {
    local k3s_paths=(
        "/host/etc/rancher/k3s/k3s.yaml"
        "/etc/rancher/k3s/k3s.yaml"
        "/var/lib/rancher/k3s/server/cred/admin.kubeconfig"
    )

    for k3s_path in "${k3s_paths[@]}"; do
        if [[ -f "$k3s_path" ]]; then
            mkdir -p "$KUBE_DIR"
            cp "$k3s_path" "$KUBE_CONFIG"
            chmod 600 "$KUBE_CONFIG"
            return 0
        fi
    done

    return 1
}

# Check if K3s config exists on host (verbose version for manual use)
detect_k3s() {
    echo -e "${YELLOW}Checking for K3s configuration...${NC}"

    local k3s_paths=(
        "/host/etc/rancher/k3s/k3s.yaml"
        "/etc/rancher/k3s/k3s.yaml"
        "/var/lib/rancher/k3s/server/cred/admin.kubeconfig"
    )

    for k3s_path in "${k3s_paths[@]}"; do
        if [[ -f "$k3s_path" ]]; then
            echo -e "${GREEN}✓ Found K3s configuration at: $k3s_path${NC}"

            mkdir -p "$KUBE_DIR"
            cp "$k3s_path" "$KUBE_CONFIG"

            # Replace server address with host.docker.internal
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

# Paste kubeconfig
paste_config() {
    mkdir -p "$KUBE_DIR"
    echo ""
    echo "Paste your kubeconfig content, then press Ctrl+D:"
    cat > "$KUBE_CONFIG"
    chmod 600 "$KUBE_CONFIG"
    echo -e "${GREEN}✓ Kubeconfig saved${NC}"
}

# Manual configuration with smart defaults
manual_config() {
    show_header
    echo -e "${CYAN}Manual Cluster Configuration${NC}"
    echo ""

    echo "Please enter the following information for your Kubernetes cluster:"
    echo ""

    # Get cluster name
    read -p "Cluster name [default]: " cluster_name
    cluster_name=${cluster_name:-default}

    # Get server URL with smart suggestions
    echo ""
    echo "Common server URLs:"
    echo "  - In-cluster: https://kubernetes.default.svc.cluster.local:443"
    echo "  - Docker/Colima: https://host.docker.internal:6443"
    echo "  - Remote: https://your-cluster.example.com:6443"
    echo ""
    read -p "Server URL: " server_url
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

    echo ""
    echo -e "${YELLOW}Testing connection to cluster...${NC}"

    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}✓ Successfully connected to cluster${NC}"
        echo ""
        kubectl cluster-info
        echo ""
        echo -e "${CYAN}Quick start:${NC}"
        echo "  kubectl get nodes          # List cluster nodes"
        echo "  kubectl get pods -A        # List all pods"
        echo "  kubectx                    # List contexts"
        echo "  k9s                        # Launch Kubernetes TUI"
        return 0
    else
        echo -e "${RED}✗ Failed to connect to cluster${NC}"
        echo -e "${YELLOW}  Check your configuration and network connectivity${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  - Verify server URL is correct"
        echo "  - Check network connectivity to cluster"
        echo "  - Ensure credentials are valid"
        echo "  - For in-cluster: verify service account has permissions"
        return 1
    fi
}

# Interactive mode
interactive_mode() {
    show_header

    echo "Choose a configuration method:"
    echo ""
    echo "  1) Auto-detect (recommended) - Automatically detect and configure"
    echo "  2) In-cluster access - Use service account credentials"
    echo "  3) K3s from host - Detect K3s configuration"
    echo "  4) Manual configuration - Enter cluster details"
    echo "  5) Paste kubeconfig - Paste existing config"
    echo "  6) Show current contexts"
    echo "  7) Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice

    case $choice in
        1)
            auto_detect && test_connection
            ;;
        2)
            configure_in_cluster && test_connection
            ;;
        3)
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
        4)
            manual_config && test_connection
            ;;
        5)
            paste_config && test_connection
            ;;
        6)
            show_contexts
            ;;
        7)
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
        --in-cluster)
            configure_in_cluster && test_connection
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
