#!/bin/bash
# Generate ConfigMap for init container scripts

# Use standard devuser home from environment or default
DEVUSER_HOME="${DEVUSER_HOME:-/home/devuser}"

generate_init_scripts_configmap() {
    local output_file="$1"
    
    cat > "$output_file" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: init-scripts
  namespace: ai-devkit
data:
  init-copy.sh: |
    #!/bin/sh
    # Init Container Copy Script
    # This script runs in the init container to copy files from ConfigMap to their destinations
    
    set -e
    
    MANIFEST_FILE="/config-data/manifest.txt"
    CONFIG_DATA_DIR="/config-data"
    
    echo "AI DevKit Init Container - Setting up configuration files"
    echo "========================================================="
    
    if [ ! -f "$MANIFEST_FILE" ]; then
        echo "ERROR: Manifest file not found at $MANIFEST_FILE"
        exit 1
    fi
    
    # Process manifest line by line
    # Format: source|destination|mode|owner
    line_num=0
    while IFS='|' read -r source dest mode owner || [ -n "$source" ]; do
        line_num=$((line_num + 1))
        
        # Skip comments and empty lines
        case "$source" in
            "#"*|"")
                continue
                ;;
        esac
        
        # Construct full source path (with - replacing / in key names)
        source_key=$(echo "$source" | tr '/' '-')
        full_source="${CONFIG_DATA_DIR}/${source_key}"
        
        # Check if source exists
        if [ ! -f "$full_source" ]; then
            echo "WARNING: Source file not found: $full_source (line $line_num)"
            continue
        fi
        
        # Create destination directory
        dest_dir=$(dirname "$dest")
        if [ ! -d "$dest_dir" ]; then
            echo "Creating directory: $dest_dir"
            mkdir -p "$dest_dir"
        fi
        
        # Copy file
        echo "Copying: $source -> $dest"
        cp "$full_source" "$dest"
        
        # Set permissions if specified
        if [ -n "$mode" ] && [ "$mode" != "default" ]; then
            chmod "$mode" "$dest" 2>/dev/null || echo "  Warning: Could not set mode $mode on $dest"
        fi
        
    done < "$MANIFEST_FILE"
    
    echo ""
    echo "Configuration setup complete!"
    echo "========================================================="
    
    # List what was set up for debugging
    echo "Files configured:"
    find ${DEVUSER_HOME}/.config -type f 2>/dev/null | head -20 || true
    find ${DEVUSER_HOME}/.ai-devkit -type f 2>/dev/null | head -20 || true
    
    exit 0
EOF
}

# Export the function
export -f generate_init_scripts_configmap