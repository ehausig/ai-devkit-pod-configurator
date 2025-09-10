#!/bin/bash
# Multi-platform container runtime cleanup script
# Supports Colima, K3s, containerd, Docker Desktop, and other Kubernetes environments
# Replaces the original cleanup-colima.sh with cross-platform support

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Utility functions
log() { echo -e "${2:-$YELLOW}$1${NC}"; }
error() { log "Error: $1" "$RED"; exit 1; }
success() { log "$1" "$GREEN"; }
info() { log "$1" "$BLUE"; }
warning() { log "$1" "$MAGENTA"; }

# Global variables
FORCE_MODE=false
OVERLAY2_CLEANUP=false
SKIP_OVERLAY2=false

# Container Tool Detection System (copied from build-and-deploy.sh)
CONTAINER_TOOL_CONFIG="$HOME/.ai-devkit/container-tool"

detect_container_tool() {
    # Detect available container tool (docker or podman)
    # Returns: "docker", "podman", or "none"
    
    # Check if we have a cached preference
    if [[ -f "$CONTAINER_TOOL_CONFIG" ]]; then
        local cached_tool=$(cat "$CONTAINER_TOOL_CONFIG" 2>/dev/null)
        if [[ -n "$cached_tool" ]] && command -v "$cached_tool" &> /dev/null; then
            # Verify the cached tool is still working
            if "$cached_tool" version &> /dev/null; then
                echo "$cached_tool"
                return 0
            fi
        fi
        # Cache is invalid, remove it
        rm -f "$CONTAINER_TOOL_CONFIG" 2>/dev/null || true
    fi
    
    # Auto-detect available tools - prefer Docker if both are available
    if command -v docker &> /dev/null && docker version &> /dev/null 2>&1; then
        echo "docker"
        return 0
    elif command -v podman &> /dev/null && podman version &> /dev/null 2>&1; then
        echo "podman"
        return 0
    fi
    
    echo "none"
    return 1
}

get_container_tool() {
    # Get the configured container tool
    local tool=$(detect_container_tool)
    
    if [[ "$tool" == "none" ]]; then
        error "No container tool found. Please install either Docker or Podman."
    fi
    
    echo "$tool"
}

# Container tool abstraction functions for cleanup operations
container_images() {
    local tool=$(get_container_tool)
    case "$tool" in
        "docker") docker images "$@" ;;
        "podman") podman images "$@" ;;
        *) error "Unsupported container tool: $tool" ;;
    esac
}

container_system_df() {
    local tool=$(get_container_tool)
    case "$tool" in
        "docker") docker system df "$@" ;;
        "podman") podman system df "$@" 2>/dev/null || echo "Podman system df not available" ;;
        *) error "Unsupported container tool: $tool" ;;
    esac
}

container_system_prune() {
    local tool=$(get_container_tool)
    case "$tool" in
        "docker") docker system prune "$@" ;;
        "podman") podman system prune "$@" ;;
        *) error "Unsupported container tool: $tool" ;;
    esac
}

container_builder_prune() {
    local tool=$(get_container_tool)
    case "$tool" in
        "docker") docker builder prune "$@" ;;
        "podman") 
            # Podman doesn't have builder prune, but we can clean build cache
            podman system prune "$@" 2>/dev/null || true
            ;;
        *) error "Unsupported container tool: $tool" ;;
    esac
}

container_tag() {
    local tool=$(get_container_tool)
    case "$tool" in
        "docker") docker tag "$@" ;;
        "podman") podman tag "$@" ;;
        *) error "Unsupported container tool: $tool" ;;
    esac
}

container_rmi() {
    local tool=$(get_container_tool)
    case "$tool" in
        "docker") docker rmi "$@" ;;
        "podman") podman rmi "$@" ;;
        *) error "Unsupported container tool: $tool" ;;
    esac
}

container_inspect() {
    local tool=$(get_container_tool)
    case "$tool" in
        "docker") docker inspect "$@" ;;
        "podman") podman inspect "$@" ;;
        *) error "Unsupported container tool: $tool" ;;
    esac
}

# Runtime detection functions (copied from build-and-deploy.sh)
detect_container_runtime() {
    # Detect the container runtime environment
    # Returns: "colima", "k3s", "containerd", "docker-desktop", or "unknown"
    
    # Check for Colima first
    if command -v colima &> /dev/null && colima status &> /dev/null; then
        echo "colima"
        return 0
    fi
    
    # Check for K3s
    if command -v k3s &> /dev/null && sudo systemctl is-active --quiet k3s 2>/dev/null; then
        echo "k3s"
        return 0
    fi
    
    # Check for standalone containerd
    if command -v ctr &> /dev/null && sudo ctr version &> /dev/null 2>&1; then
        echo "containerd"
        return 0
    fi
    
    # Check for Docker Desktop (macOS/Windows) or Podman Desktop
    local container_tool=$(detect_container_tool)
    if [[ "$container_tool" == "docker" ]] && docker context show 2>/dev/null | grep -q "desktop\|docker-desktop"; then
        echo "docker-desktop"
        return 0
    elif [[ "$container_tool" == "podman" ]]; then
        # For Podman, check if this might be a desktop environment
        if kubectl get nodes &> /dev/null; then
            local runtime=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' 2>/dev/null)
            if [[ "$runtime" == *"cri-o"* ]] || [[ "$runtime" == *"podman"* ]]; then
                echo "podman"
                return 0
            fi
        fi
    fi
    
    # Check if we can access Kubernetes cluster directly
    if kubectl get nodes &> /dev/null; then
        # Determine runtime by checking node container runtime
        local runtime=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' 2>/dev/null)
        case "$runtime" in
            containerd*)
                echo "containerd"
                return 0
                ;;
            docker*)
                echo "docker"
                return 0
                ;;
            cri-o*)
                echo "cri-o"
                return 0
                ;;
        esac
    fi
    
    # Default fallback
    echo "unknown"
    return 1
}

# Check if Kubernetes is healthy before proceeding
check_kubernetes_health() {
    if kubectl version --client &> /dev/null 2>&1; then
        log "\nChecking Kubernetes health..."
        
        # Check if all system pods are running
        local not_running=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v "Running" | wc -l || echo "0")
        
        if [[ $not_running -gt 0 ]]; then
            error "Kubernetes system pods are not healthy. Please fix k8s before running cleanup:\nkubectl get pods -n kube-system"
        else
            success "✓ All Kubernetes system pods are running"
        fi
    fi
}

# Check runtime status based on detected type
check_runtime() {
    local runtime=$(detect_container_runtime)
    
    case "$runtime" in
        "colima")
            if ! command -v colima &> /dev/null; then
                error "Colima is not installed or not in PATH"
            fi
            if ! colima status &> /dev/null; then
                error "Colima is not running. Please start it with: colima start"
            fi
            ;;
        "k3s")
            if ! command -v k3s &> /dev/null; then
                error "K3s is not installed or not in PATH"
            fi
            if ! sudo systemctl is-active --quiet k3s; then
                error "K3s is not running. Please start it with: sudo systemctl start k3s"
            fi
            ;;
        "docker-desktop")
            local tool=$(get_container_tool)
            if ! $tool info &> /dev/null; then
                error "$tool Desktop is not running. Please start $tool Desktop"
            fi
            ;;
        "containerd")
            if ! sudo ctr version &> /dev/null; then
                error "Containerd is not accessible. Please check containerd service"
            fi
            ;;
        *)
            warning "Unknown runtime: $runtime. Proceeding with caution..."
            ;;
    esac
}

# Get list of protected images that should never be removed
get_protected_images() {
    # These are critical k8s/k3s images
    local protected_patterns=(
        "rancher/mirrored-pause"
        "rancher/mirrored-coredns"
        "rancher/mirrored-metrics-server" 
        "rancher/local-path-provisioner"
        "rancher/klipper-helm"
        "rancher/klipper-lb"
        "k8s.gcr.io/pause"
        "registry.k8s.io/pause"
    )
    
    local runtime=$(detect_container_runtime)
    local protected_ids=""
    
    # Get image IDs of protected images
    for pattern in "${protected_patterns[@]}"; do
        local ids=""
        case "$runtime" in
            "colima")
                ids=$(colima ssh -- sudo docker images --filter "reference=$pattern*" -q 2>/dev/null)
                ;;
            "docker-desktop")
                ids=$(container_images --filter "reference=$pattern*" -q 2>/dev/null)
                ;;
            *)
                ids=$(container_images --filter "reference=$pattern*" -q 2>/dev/null)
                ;;
        esac
        
        if [[ -n "$ids" ]]; then
            protected_ids+="$ids "
        fi
    done
    
    echo "$protected_ids"
}

# Show disk usage before cleanup
show_disk_usage() {
    local runtime=$(detect_container_runtime)
    
    info "=== Disk Usage Analysis ==="
    
    case "$runtime" in
        "colima")
            info "Colima VM disk usage:"
            colima ssh -- df -h / | grep -E "Filesystem|/$"
            
            # Show Docker overlay2 usage specifically
            local overlay_size=$(colima ssh -- sudo du -sh /var/lib/docker/overlay2/ 2>/dev/null | cut -f1)
            if [[ -n "$overlay_size" ]]; then
                echo "Docker overlay2: $overlay_size"
            fi
            ;;
        "k3s"|"containerd")
            info "Host system disk usage:"
            df -h / | grep -E "Filesystem|/$"
            
            # Show containerd usage
            local containerd_size=$(sudo du -sh /var/lib/containerd/ 2>/dev/null | cut -f1)
            if [[ -n "$containerd_size" ]]; then
                echo "Containerd data: $containerd_size"
            fi
            ;;
        "docker-desktop")
            info "Docker Desktop disk usage:"
            df -h / | grep -E "Filesystem|/$"
            docker system df
            ;;
        *)
            info "System disk usage:"
            df -h / | grep -E "Filesystem|/$"
            if command -v docker &> /dev/null; then
                docker system df 2>/dev/null || true
            fi
            ;;
    esac
    echo ""
}

# Clean Docker resources based on runtime
clean_docker() {
    local runtime=$(detect_container_runtime)
    log "Cleaning Docker/container resources for $runtime runtime..."
    
    # Get protected images
    local protected_images=$(get_protected_images)
    
    # Show current disk usage
    info "Current container disk usage:"
    case "$runtime" in
        "colima")
            colima ssh -- sudo docker system df
            ;;
        "docker-desktop")
            container_system_df
            ;;
        *)
            container_system_df 2>/dev/null || sudo ctr images list 2>/dev/null || true
            ;;
    esac
    echo ""
    
    if [[ -n "$protected_images" ]]; then
        info "Protected images (will not be removed):"
        echo "$protected_images" | tr ' ' '\n' | while read -r id; do
            if [[ -n "$id" ]]; then
                case "$runtime" in
                    "colima")
                        colima ssh -- sudo docker images | grep "$id" | head -1 || true
                        ;;
                    *)
                        docker images | grep "$id" | head -1 || true
                        ;;
                esac
            fi
        done
        echo ""
    fi
    
    # Clean up with user confirmation
    if [[ "$FORCE_MODE" == "true" ]] || confirm "Clean up unused container resources (excluding k8s system images)?"; then
        log "Running container system cleanup (excluding k8s images)..."
        
        case "$runtime" in
            "colima")
                # Tag protected images to prevent removal
                echo "$protected_images" | tr ' ' '\n' | while read -r id; do
                    if [[ -n "$id" ]]; then
                        colima ssh -- sudo docker tag "$id" "protected:keep-$id" 2>/dev/null || true
                    fi
                done
                
                # Run prune
                colima ssh -- sudo docker system prune -a --volumes -f
                colima ssh -- sudo docker builder prune -a -f
                
                # Remove protection tags
                echo "$protected_images" | tr ' ' '\n' | while read -r id; do
                    if [[ -n "$id" ]]; then
                        colima ssh -- sudo docker rmi "protected:keep-$id" 2>/dev/null || true
                    fi
                done
                ;;
            "k3s")
                # K3s uses containerd
                info "Cleaning K3s/containerd images..."
                sudo k3s ctr images prune --keep-duration=0 || true
                ;;
            "containerd")
                info "Cleaning containerd images..."
                sudo ctr images prune --keep-duration=0 || true
                ;;
            "docker-desktop")
                # Tag protected images
                echo "$protected_images" | tr ' ' '\n' | while read -r id; do
                    if [[ -n "$id" ]]; then
                        docker tag "$id" "protected:keep-$id" 2>/dev/null || true
                    fi
                done
                
                # Run prune
                docker system prune -a --volumes -f
                docker builder prune -a -f
                
                # Remove protection tags
                echo "$protected_images" | tr ' ' '\n' | while read -r id; do
                    if [[ -n "$id" ]]; then
                        docker rmi "protected:keep-$id" 2>/dev/null || true
                    fi
                done
                ;;
            *)
                warning "Unknown runtime. Attempting generic Docker cleanup..."
                docker system prune -a --volumes -f || true
                ;;
        esac
        
        success "✓ Container cleanup completed (k8s images preserved)"
    else
        log "Skipping container cleanup"
    fi
}

# Clean orphaned overlay2 directories (Colima-specific)
clean_overlay2_orphans() {
    local runtime=$(detect_container_runtime)
    
    if [[ "$runtime" != "colima" ]]; then
        info "Overlay2 cleanup is only applicable to Colima environments"
        return 0
    fi
    
    log "\nChecking for orphaned Docker overlay2 directories..."
    
    # Create temporary script to run inside Colima
    local cleanup_script=$(cat << 'SCRIPT'
#!/bin/bash
# Get directories in use by images
sudo docker inspect $(sudo docker images -q) 2>/dev/null | grep -o '/var/lib/docker/overlay2/[^"]*' | cut -d'/' -f6 | sort -u > /tmp/used_dirs.txt

# Get directories in use by containers
sudo docker inspect $(sudo docker ps -q) 2>/dev/null | grep -o '/var/lib/docker/overlay2/[^"]*' | cut -d'/' -f6 | sort -u >> /tmp/used_dirs.txt

# Remove duplicates
sort -u /tmp/used_dirs.txt -o /tmp/used_dirs.txt

# Get all directories
sudo ls /var/lib/docker/overlay2/ > /tmp/all_dirs.txt

# Find orphaned ones
comm -23 <(sort /tmp/all_dirs.txt) <(sort /tmp/used_dirs.txt) > /tmp/orphaned_dirs.txt

# Count and show statistics
total_dirs=$(wc -l < /tmp/all_dirs.txt)
used_dirs=$(wc -l < /tmp/used_dirs.txt)
orphaned_dirs=$(wc -l < /tmp/orphaned_dirs.txt)

echo "Total overlay2 directories: $total_dirs"
echo "Directories in use: $used_dirs"
echo "Orphaned directories: $orphaned_dirs"

# Return the count
echo "$orphaned_dirs"
SCRIPT
)
    
    # Execute the script and get orphan count
    local result=$(colima ssh -- bash -c "$cleanup_script")
    local orphan_count=$(echo "$result" | tail -1)
    
    # Show output except the last line
    local line_count=$(echo "$result" | wc -l)
    if [[ $line_count -gt 1 ]]; then
        echo "$result" | head -n $((line_count - 1))
    fi
    
    if [[ "$orphan_count" -gt 0 ]]; then
        warning "\nFound $orphan_count orphaned overlay2 directories!"
        
        if [[ "$FORCE_MODE" == "true" ]] || confirm "Remove orphaned overlay2 directories? This may free significant space."; then
            log "Removing orphaned directories (this may take a while)..."
            
            # Create removal script
            local removal_script='#!/bin/bash
if [ -f /tmp/orphaned_dirs.txt ]; then
    # Stop Docker to ensure safety
    sudo systemctl stop docker
    
    # Remove orphaned directories
    while IFS= read -r dir; do
        if [ -n "$dir" ]; then
            sudo rm -rf "/var/lib/docker/overlay2/$dir"
        fi
    done < /tmp/orphaned_dirs.txt
    
    # Restart Docker
    sudo systemctl start docker
    
    echo "Cleanup completed"
else
    echo "Error: orphaned_dirs.txt not found"
    exit 1
fi'
            
            # Execute the removal script
            colima ssh -- bash -c "$removal_script"
            
            success "✓ Orphaned overlay2 directories removed"
            
            # Show space recovered
            info "Checking space recovered..."
            show_disk_usage
        else
            log "Skipping overlay2 cleanup"
        fi
    else
        success "✓ No orphaned overlay2 directories found"
    fi
    
    # Cleanup temp files
    colima ssh -- rm -f /tmp/used_dirs.txt /tmp/all_dirs.txt /tmp/orphaned_dirs.txt 2>/dev/null || true
}

# Clean Kubernetes resources
clean_kubernetes() {
    if kubectl version --client &> /dev/null 2>&1; then
        log "\nCleaning Kubernetes resources..."
        
        # Clean failed and succeeded pods
        info "Looking for terminated pods..."
        
        local failed_pods=$(kubectl get pods --all-namespaces --field-selector status.phase=Failed -o json 2>/dev/null | jq '.items | length' || echo "0")
        local succeeded_pods=$(kubectl get pods --all-namespaces --field-selector status.phase=Succeeded -o json 2>/dev/null | jq '.items | length' || echo "0")
        
        if [[ $failed_pods -gt 0 ]] || [[ $succeeded_pods -gt 0 ]]; then
            echo "Found $failed_pods failed pods and $succeeded_pods succeeded pods"
            
            if [[ "$FORCE_MODE" == "true" ]] || confirm "Delete all terminated pods?"; then
                kubectl delete pod --field-selector status.phase=Failed -A --ignore-not-found=true
                kubectl delete pod --field-selector status.phase=Succeeded -A --ignore-not-found=true
                success "✓ Kubernetes cleanup completed"
            else
                log "Skipping Kubernetes cleanup"
            fi
        else
            info "No terminated pods found"
        fi
        
        # Check for orphaned PVCs
        local pvcs=$(kubectl get pvc -A -o json 2>/dev/null | jq '.items | length' || echo "0")
        if [[ $pvcs -gt 0 ]]; then
            info "\nFound $pvcs PVCs across all namespaces"
            kubectl get pvc -A
            
            if [[ "$FORCE_MODE" == "true" ]] || confirm "Review and delete unused PVCs?"; then
                warning "Please manually review and delete unused PVCs with: kubectl delete pvc <name> -n <namespace>"
            fi
        fi
    else
        info "kubectl not found, skipping Kubernetes cleanup"
    fi
}

# Check for disk pressure taint
check_disk_pressure() {
    if kubectl version --client &> /dev/null 2>&1; then
        log "\nChecking for disk pressure on nodes..."
        
        local disk_pressure=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[].spec.taints[]? | select(.key == "node.kubernetes.io/disk-pressure") | .key' 2>/dev/null)
        
        if [[ -n "$disk_pressure" ]]; then
            local runtime=$(detect_container_runtime)
            warning "⚠ Node has disk pressure taint! You may need to:"
            echo "  • Free more space using this script"
            case "$runtime" in
                "colima")
                    echo "  • Restart Colima: colima restart"
                    echo "  • Increase disk size: colima stop && colima delete && colima start --disk 100"
                    ;;
                "k3s")
                    echo "  • Restart K3s: sudo systemctl restart k3s"
                    echo "  • Clean up host disk space"
                    ;;
                "docker-desktop")
                    echo "  • Restart Docker Desktop"
                    echo "  • Increase Docker Desktop disk allocation"
                    ;;
                *)
                    echo "  • Check available disk space on host"
                    echo "  • Restart container runtime service"
                    ;;
            esac
        else
            success "✓ No disk pressure detected on nodes"
        fi
    fi
}

# Confirmation helper
confirm() {
    if [[ "$FORCE_MODE" == "true" ]]; then
        return 0
    fi
    
    read -p "$(echo -e ${YELLOW}$1 [y/N]: ${NC})" -n 1 -r
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Show cleanup summary
show_summary() {
    log "\n=== Cleanup Summary ==="
    
    local runtime=$(detect_container_runtime)
    info "Container runtime: $runtime"
    
    # Show final disk usage
    show_disk_usage
}

# Main execution
main() {
    local runtime=$(detect_container_runtime)
    log "=== Multi-Platform Container Runtime Cleanup ==="
    info "Detected runtime: $runtime"
    echo ""
    
    check_runtime
    check_kubernetes_health  # Ensure k8s is healthy before proceeding
    
    # Store initial state
    show_disk_usage
    
    # Perform cleanup steps
    clean_docker
    
    # Only clean overlay2 for Colima if explicitly requested
    if [[ "$OVERLAY2_CLEANUP" == "true" ]] || [[ "$FORCE_MODE" == "true" && "$SKIP_OVERLAY2" != "true" ]]; then
        clean_overlay2_orphans
    else
        if [[ "$runtime" == "colima" ]]; then
            info "\nSkipping overlay2 cleanup (use --overlay2 to enable)"
        fi
    fi
    
    clean_kubernetes
    
    # Check for disk pressure
    check_disk_pressure
    
    # Show summary
    show_summary
    
    # Provide runtime-specific additional options
    echo ""
    info "Additional cleanup options for $runtime:"
    case "$runtime" in
        "colima")
            echo "  • To clean overlay2 directories: $0 --overlay2"
            echo "  • To check largest directories: colima ssh -- sudo du -h /var/lib/docker/ --max-depth=2 | sort -rh | head -20"
            echo "  • To clean journal logs: colima ssh -- sudo journalctl --vacuum-size=100M"
            echo "  • To restart Colima fresh: colima restart"
            echo "  • To increase disk size: colima stop && colima delete && colima start --disk 100"
            ;;
        "k3s")
            echo "  • To check largest directories: sudo du -h /var/lib/containerd/ --max-depth=2 | sort -rh | head -20"
            echo "  • To clean journal logs: sudo journalctl --vacuum-size=100M"
            echo "  • To restart K3s: sudo systemctl restart k3s"
            echo "  • To reset K3s completely: /usr/local/bin/k3s-uninstall.sh && curl -sfL https://get.k3s.io | sh -"
            ;;
        "docker-desktop")
            echo "  • To check Docker usage: docker system df"
            echo "  • To clean build cache: docker builder prune"
            echo "  • To restart Docker Desktop: restart from Docker Desktop UI"
            echo "  • To increase disk allocation: Docker Desktop Settings > Resources > Disk"
            ;;
        *)
            echo "  • To check container usage: docker system df || sudo ctr images list"
            echo "  • To clean manually: docker/ctr cleanup commands"
            echo "  • To restart runtime: check your container runtime documentation"
            ;;
    esac
    
    success "\nCleanup completed!"
}

# Handle command line arguments
case "${1:-}" in
    --force|-f)
        FORCE_MODE=true
        log "Running in force mode (no confirmations)..."
        ;;
    --overlay2)
        OVERLAY2_CLEANUP=true
        log "Overlay2 cleanup enabled..."
        ;;
    --safe)
        SKIP_OVERLAY2=true
        log "Running in safe mode (overlay2 cleanup disabled)..."
        ;;
    --check|-c)
        # Check mode - only show what would be cleaned
        runtime=$(detect_container_runtime)
        info "Detected runtime: $runtime"
        check_runtime
        show_disk_usage
        
        log "\nChecking for cleanable resources..."
        
        # Check containers
        case "$runtime" in
            "colima")
                info "Docker resources:"
                colima ssh -- sudo docker system df
                ;;
            "docker-desktop")
                info "Docker resources:"
                docker system df
                ;;
            *)
                info "Container resources:"
                docker system df 2>/dev/null || sudo ctr images list 2>/dev/null || info "Unable to check container resources"
                ;;
        esac
        
        # Check k8s
        if kubectl version --client &> /dev/null 2>&1; then
            info "\nKubernetes resources:"
            local failed=$(kubectl get pods --all-namespaces --field-selector status.phase=Failed --no-headers 2>/dev/null | wc -l || echo "0")
            local succeeded=$(kubectl get pods --all-namespaces --field-selector status.phase=Succeeded --no-headers 2>/dev/null | wc -l || echo "0")
            echo "Failed pods: $failed"
            echo "Succeeded pods: $succeeded"
        fi
        
        check_disk_pressure
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Multi-platform container runtime cleanup script"
        echo "Supports: Colima, K3s, containerd, Docker Desktop, and generic Docker"
        echo ""
        echo "Options:"
        echo "  -f, --force      Skip confirmation prompts"
        echo "  --overlay2       Enable overlay2 cleanup (Colima only)"
        echo "  --safe           Safe mode - skip overlay2 cleanup even in force mode"
        echo "  -c, --check      Check what can be cleaned without making changes"
        echo "  -h, --help       Show this help message"
        echo ""
        echo "This script helps clean up disk space by:"
        echo "  • Removing unused container images, containers, and volumes"
        echo "  • Preserving critical k8s system images"
        echo "  • Deleting terminated Kubernetes pods"
        echo "  • Checking for disk pressure on nodes"
        echo "  • Platform-specific cleanup (e.g., overlay2 for Colima)"
        echo ""
        echo "Supported Runtimes:"
        echo "  • Colima (macOS Docker/Kubernetes)"
        echo "  • K3s (lightweight Kubernetes)"
        echo "  • Docker Desktop (macOS/Windows)"
        echo "  • Generic containerd"
        echo "  • Generic Docker"
        echo ""
        echo "Examples:"
        echo "  $0                    # Auto-detect runtime and clean safely"
        echo "  $0 --force            # Force mode (skip confirmations)"
        echo "  $0 --check            # See what would be cleaned"
        echo "  $0 --overlay2         # Enable overlay2 cleanup (Colima only)"
        exit 0
        ;;
esac

# Run main function
main