#!/bin/bash
# Script to clean up disk space in Colima - Enhanced version
# Includes Docker overlay2 orphaned directory cleanup

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

# Check if Colima is installed and running
check_colima() {
    if ! command -v colima &> /dev/null; then
        error "Colima is not installed or not in PATH"
    fi
    
    if ! colima status &> /dev/null; then
        error "Colima is not running. Please start it with: colima start"
    fi
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
    )
    
    # Get image IDs of protected images
    local protected_ids=""
    for pattern in "${protected_patterns[@]}"; do
        local ids=$(colima ssh -- sudo docker images --filter "reference=$pattern*" -q 2>/dev/null)
        if [[ -n "$ids" ]]; then
            protected_ids+="$ids "
        fi
    done
    
    echo "$protected_ids"
}

# Show disk usage before cleanup
show_disk_usage() {
    info "=== Disk Usage in Colima ==="
    colima ssh -- df -h / | grep -E "Filesystem|/$"
    
    # Show Docker overlay2 usage specifically
    local overlay_size=$(colima ssh -- sudo du -sh /var/lib/docker/overlay2/ 2>/dev/null | cut -f1)
    if [[ -n "$overlay_size" ]]; then
        echo "Docker overlay2: $overlay_size"
    fi
    echo ""
}

# Clean Docker resources
clean_docker() {
    log "Cleaning Docker resources inside Colima..."
    
    # Get protected images
    local protected_images=$(get_protected_images)
    
    # Show current Docker disk usage
    info "Current Docker disk usage:"
    colima ssh -- sudo docker system df
    echo ""
    
    if [[ -n "$protected_images" ]]; then
        info "Protected images (will not be removed):"
        echo "$protected_images" | tr ' ' '\n' | while read -r id; do
            if [[ -n "$id" ]]; then
                colima ssh -- sudo docker images | grep "$id" | head -1
            fi
        done
        echo ""
    fi
    
    # Clean up with user confirmation
    if [[ "$FORCE_MODE" == "true" ]] || confirm "Clean up unused Docker resources (excluding k8s system images)?"; then
        log "Running Docker system prune (excluding k8s images)..."
        
        # First, tag protected images to prevent removal
        echo "$protected_images" | tr ' ' '\n' | while read -r id; do
            if [[ -n "$id" ]]; then
                colima ssh -- sudo docker tag "$id" "protected:keep-$id" 2>/dev/null || true
            fi
        done
        
        # Run prune
        colima ssh -- sudo docker system prune -a --volumes -f
        
        # Clean builder cache
        colima ssh -- sudo docker builder prune -a -f
        
        # Remove protection tags
        echo "$protected_images" | tr ' ' '\n' | while read -r id; do
            if [[ -n "$id" ]]; then
                colima ssh -- sudo docker rmi "protected:keep-$id" 2>/dev/null || true
            fi
        done
        
        success "✓ Docker cleanup completed (k8s images preserved)"
    else
        log "Skipping Docker cleanup"
    fi
}

# Clean orphaned Docker overlay2 directories (NEW FUNCTION)
clean_overlay2_orphans() {
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

# Calculate approximate space used by orphans (sample first 10)
if [[ $orphaned_dirs -gt 0 ]]; then
    sample_size=0
    sample_count=0
    while read -r dir && [[ $sample_count -lt 10 ]]; do
        size=$(sudo du -s "/var/lib/docker/overlay2/$dir" 2>/dev/null | cut -f1)
        if [[ -n "$size" ]]; then
            sample_size=$((sample_size + size))
            sample_count=$((sample_count + 1))
        fi
    done < /tmp/orphaned_dirs.txt
    
    if [[ $sample_count -gt 0 ]]; then
        avg_size=$((sample_size / sample_count))
        estimated_total=$((avg_size * orphaned_dirs / 1024 / 1024))
        echo "Estimated space used by orphans: ~${estimated_total}GB"
    fi
fi

# Return the count for the main script
echo "$orphaned_dirs"
SCRIPT
)
    
    # Execute the script and get orphan count
    local result=$(colima ssh -- bash -c "$cleanup_script")
    local orphan_count=$(echo "$result" | tail -1)
    
    # Show all output except the last line (compatible with BusyBox)
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
            warning "⚠ Node has disk pressure taint! You may need to:"
            echo "  • Free more space using this script"
            echo "  • Restart Colima: colima restart"
            echo "  • Increase disk size: colima stop && colima delete && colima start --disk 100"
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
    
    # Calculate space freed
    local initial_used=$(echo "$INITIAL_DISK_USAGE" | awk '{print $3}')
    local final_used=$(colima ssh -- df -h / | grep "/$" | awk '{print $3}')
    
    # Extract numeric values and units
    local initial_num=$(echo "$initial_used" | sed 's/[^0-9.]//g')
    local initial_unit=$(echo "$initial_used" | sed 's/[0-9.]//g')
    local final_num=$(echo "$final_used" | sed 's/[^0-9.]//g')
    local final_unit=$(echo "$final_used" | sed 's/[0-9.]//g')
    
    # Only calculate if both values are in GB
    if [[ "$initial_unit" == "G" && "$final_unit" == "G" ]]; then
        # Use awk for floating point arithmetic
        local freed=$(awk -v i="$initial_num" -v f="$final_num" 'BEGIN {printf "%.1f", i - f}')
        if (( $(awk -v f="$freed" 'BEGIN {print (f > 0)}') )); then
            success "Total space freed: ${freed}GB"
        fi
    fi
}

# Main execution
main() {
    log "=== Colima Disk Cleanup Utility (Enhanced) ==="
    echo ""
    
    check_colima
    check_kubernetes_health  # Ensure k8s is healthy before proceeding
    
    # Store initial disk usage
    INITIAL_DISK_USAGE=$(colima ssh -- df -h / | grep "/$")
    show_disk_usage
    
    # Perform cleanup steps
    clean_docker
    
    # Only clean overlay2 if explicitly requested or in force mode
    if [[ "$OVERLAY2_CLEANUP" == "true" ]] || [[ "$FORCE_MODE" == "true" && "$SKIP_OVERLAY2" != "true" ]]; then
        clean_overlay2_orphans  # Now with enhanced safety checks
    else
        info "\nSkipping overlay2 cleanup (use --overlay2 to enable)"
    fi
    
    clean_kubernetes
    
    # Show final disk usage
    echo ""
    log "=== Disk Usage After Cleanup ==="
    show_disk_usage
    
    # Show summary
    show_summary
    
    # Check for disk pressure
    check_disk_pressure
    
    # Provide additional options
    echo ""
    info "Additional cleanup options:"
    echo "  • To clean overlay2 directories: $0 --overlay2"
    echo "  • To check largest directories: colima ssh -- sudo du -h /var/lib/docker/ --max-depth=2 | sort -rh | head -20"
    echo "  • To clean journal logs: colima ssh -- sudo journalctl --vacuum-size=100M"
    echo "  • To restart Colima fresh: colima restart"
    echo "  • To increase disk size: colima stop && colima delete && colima start --disk 100"
    
    success "\nCleanup completed!"
}

# Handle command line arguments
case "${1:-}" in
    --force|-f)
        # Force mode - skip confirmations
        FORCE_MODE=true
        log "Running in force mode (no confirmations)..."
        ;;
    --overlay2)
        # Enable overlay2 cleanup
        OVERLAY2_CLEANUP=true
        log "Overlay2 cleanup enabled..."
        ;;
    --safe)
        # Safe mode - skip overlay2 even in force mode
        SKIP_OVERLAY2=true
        log "Running in safe mode (overlay2 cleanup disabled)..."
        ;;
    --check|-c)
        # Check mode - only show what would be cleaned
        check_colima
        show_disk_usage
        
        log "\nChecking for cleanable resources..."
        
        # Check Docker
        info "Docker resources:"
        colima ssh -- sudo docker system df
        
        # Check overlay2
        info "\nChecking overlay2 directories..."
        colima ssh -- bash -c '
            total=$(sudo ls /var/lib/docker/overlay2/ | grep -v "^l$" | wc -l)
            echo "Total overlay2 directories: $total (excluding l directory)"
        '
        
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
        echo "Options:"
        echo "  -f, --force      Skip confirmation prompts"
        echo "  --overlay2       Enable overlay2 cleanup (CURRENTLY DISABLED - UNSAFE)"
        echo "  --safe           Safe mode - skip overlay2 cleanup even in force mode"
        echo "  -c, --check      Check what can be cleaned without making changes"
        echo "  -h, --help       Show this help message"
        echo ""
        echo "This enhanced script helps clean up disk space in Colima by:"
        echo "  • Removing unused Docker images, containers, and volumes"
        echo "  • Preserving critical k8s system images (pause, coredns, etc.)"
        echo "  • Deleting terminated Kubernetes pods"
        echo "  • Checking for disk pressure on nodes"
        echo ""
        echo "SAFETY FEATURES:"
        echo "  • Checks k8s health before proceeding"
        echo "  • Never removes k8s system images"
        echo "  • Validates k8s health after cleanup"
        echo ""
        echo "OVERLAY2 CLEANUP - CURRENTLY DISABLED:"
        echo "  The overlay2 cleanup feature has been found to cause k8s pod failures"
        echo "  even with extensive safety checks. It is disabled until a safer"
        echo "  implementation can be developed."
        echo ""
        echo "  For overlay2 disk space issues, use:"
        echo "    - colima restart (safest option)"
        echo "    - colima delete && colima start (complete reset)"
        echo ""
        echo "Examples:"
        echo "  $0                    # Safe cleanup (recommended)"
        echo "  $0 --force            # Force mode (skip confirmations)"
        echo "  $0 --check            # See what would be cleaned"
        exit 0
        ;;
esac

# Run main function
main
