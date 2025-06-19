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

# Check if Colima is installed and running
check_colima() {
    if ! command -v colima &> /dev/null; then
        error "Colima is not installed or not in PATH"
    fi
    
    if ! colima status &> /dev/null; then
        error "Colima is not running. Please start it with: colima start"
    fi
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
    
    # Show current Docker disk usage
    info "Current Docker disk usage:"
    colima ssh -- sudo docker system df
    echo ""
    
    # Clean up with user confirmation
    if [[ "$FORCE_MODE" == "true" ]] || confirm "Clean up all unused Docker resources?"; then
        log "Running Docker system prune..."
        colima ssh -- sudo docker system prune -a --volumes -f
        
        # Also clean builder cache
        colima ssh -- sudo docker builder prune -a -f
        success "✓ Docker cleanup completed"
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
    
    # Store initial disk usage
    INITIAL_DISK_USAGE=$(colima ssh -- df -h / | grep "/$")
    show_disk_usage
    
    # Perform cleanup steps
    clean_docker
    clean_overlay2_orphans  # NEW: Clean orphaned overlay2 directories
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
            total=$(sudo ls /var/lib/docker/overlay2/ | wc -l)
            echo "Total overlay2 directories: $total"
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
        echo "  -f, --force    Skip confirmation prompts"
        echo "  -c, --check    Check what can be cleaned without making changes"
        echo "  -h, --help     Show this help message"
        echo ""
        echo "This enhanced script helps clean up disk space in Colima by:"
        echo "  • Removing unused Docker images, containers, and volumes"
        echo "  • Cleaning orphaned Docker overlay2 directories (NEW)"
        echo "  • Deleting terminated Kubernetes pods"
        echo "  • Checking for disk pressure on nodes"
        echo ""
        echo "The script now handles the common issue of orphaned overlay2"
        echo "directories that can consume significant disk space."
        exit 0
        ;;
esac

# Run main function
main
