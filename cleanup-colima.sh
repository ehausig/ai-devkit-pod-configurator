#!/bin/bash
# Script to clean up disk space in Colima

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
log() { echo -e "${2:-$YELLOW}$1${NC}"; }
error() { log "Error: $1" "$RED"; exit 1; }
success() { log "$1" "$GREEN"; }
info() { log "$1" "$BLUE"; }

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
    echo ""
}

# Clean Docker resources
clean_docker() {
    log "Cleaning Docker resources inside Colima..."
    
    # Show current Docker disk usage
    info "Current Docker disk usage:"
    colima ssh -- docker system df
    echo ""
    
    # Clean up with user confirmation
    read -p "$(echo -e ${YELLOW}Clean up all unused Docker resources? [y/N]: ${NC})" -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Running Docker system prune..."
        colima ssh -- docker system prune -a --volumes -f
        success "✓ Docker cleanup completed"
    else
        log "Skipping Docker cleanup"
    fi
}

# Clean Kubernetes resources
clean_kubernetes() {
    if kubectl version --client &> /dev/null 2>&1; then
        log "\nCleaning Kubernetes resources..."
        
        # Clean failed and succeeded pods
        info "Looking for terminated pods..."
        
        local failed_pods=$(kubectl get pods --all-namespaces --field-selector status.phase=Failed -o json | jq '.items | length')
        local succeeded_pods=$(kubectl get pods --all-namespaces --field-selector status.phase=Succeeded -o json | jq '.items | length')
        
        if [[ $failed_pods -gt 0 ]] || [[ $succeeded_pods -gt 0 ]]; then
            echo "Found $failed_pods failed pods and $succeeded_pods succeeded pods"
            
            read -p "$(echo -e ${YELLOW}Delete all terminated pods? [y/N]: ${NC})" -n 1 -r
            echo ""
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                kubectl delete pod --field-selector status.phase=Failed -A --ignore-not-found=true
                kubectl delete pod --field-selector status.phase=Succeeded -A --ignore-not-found=true
                success "✓ Kubernetes cleanup completed"
            else
                log "Skipping Kubernetes cleanup"
            fi
        else
            info "No terminated pods found"
        fi
    else
        info "kubectl not found, skipping Kubernetes cleanup"
    fi
}

# Check for disk pressure taint
check_disk_pressure() {
    if kubectl version --client &> /dev/null 2>&1; then
        log "\nChecking for disk pressure on nodes..."
        
        local disk_pressure=$(kubectl get nodes -o json | jq -r '.items[].spec.taints[]? | select(.key == "node.kubernetes.io/disk-pressure") | .key' 2>/dev/null)
        
        if [[ -n "$disk_pressure" ]]; then
            error "Node still has disk pressure taint! You may need to free more space or increase Colima's disk size."
        else
            success "✓ No disk pressure detected on nodes"
        fi
    fi
}

# Main execution
main() {
    log "=== Colima Disk Cleanup Utility ==="
    echo ""
    
    check_colima
    
    # Show initial disk usage
    show_disk_usage
    
    # Perform cleanup
    clean_docker
    clean_kubernetes
    
    # Show final disk usage
    echo ""
    log "=== Disk Usage After Cleanup ==="
    show_disk_usage
    
    # Check for disk pressure
    check_disk_pressure
    
    # Provide additional options
    echo ""
    info "Additional cleanup options:"
    echo "  • To clean build cache: colima ssh -- docker builder prune"
    echo "  • To clean specific images: colima ssh -- docker images"
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
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -f, --force    Skip confirmation prompts"
        echo "  -h, --help     Show this help message"
        echo ""
        echo "This script helps clean up disk space in Colima by:"
        echo "  • Removing unused Docker images, containers, and volumes"
        echo "  • Deleting terminated Kubernetes pods"
        echo "  • Checking for disk pressure on nodes"
        exit 0
        ;;
esac

# Run main function
main
