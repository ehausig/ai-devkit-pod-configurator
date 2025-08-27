#!/bin/bash

CONFIG_FILE="$HOME/.ai-devkit/config.yaml"

echo "Testing AWK-based YAML parsing"
echo "=============================="
echo ""

# Create a test config if needed
if [[ ! -f "$CONFIG_FILE" ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<'EOF'
# Container runtime configuration (REQUIRED)
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
fi

# Test the AWK parsing directly
echo "Testing container.build_command:"
awk -v key="container.build_command" '
    BEGIN { 
        split(key, parts, ".")
        depth = length(parts)
        found_section = 0
    }
    {
        # Get original line with spaces
        original = $0
        
        # Count leading spaces for indentation
        match(original, /^[ ]*/)
        spaces = RLENGTH
        indent_level = spaces / 2
        
        # Remove leading/trailing spaces for processing
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", original)
        
        # For two-part keys like container.build_command
        if (depth == 2) {
            # Check if we found the top-level section
            if (indent_level == 0 && original == parts[1] ":") {
                found_section = 1
                print "DEBUG: Found section: " parts[1] > "/dev/stderr"
                next
            }
            # If we are in the right section, look for the key
            if (found_section && indent_level == 1) {
                print "DEBUG: Checking line in section: " original > "/dev/stderr"
                if (original ~ "^" parts[2] ":") {
                    print "DEBUG: Found key: " parts[2] > "/dev/stderr"
                    # Extract the value
                    sub(/^[^:]+:[[:space:]]*/, "", original)
                    # Remove quotes if present
                    gsub(/^"|"$/, "", original)
                    print original
                    exit
                }
            }
            # Reset if we hit another top-level section
            if (indent_level == 0 && original ~ /^[^:]+:/) {
                found_section = 0
            }
        }
    }
' "$CONFIG_FILE"

echo ""
echo "Testing container.runtime:"
awk -v key="container.runtime" '
    BEGIN { 
        split(key, parts, ".")
        depth = length(parts)
        found_section = 0
    }
    {
        original = $0
        match(original, /^[ ]*/)
        spaces = RLENGTH
        indent_level = spaces / 2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", original)
        
        if (depth == 2) {
            if (indent_level == 0 && original == parts[1] ":") {
                found_section = 1
                next
            }
            if (found_section && indent_level == 1) {
                if (original ~ "^" parts[2] ":") {
                    sub(/^[^:]+:[[:space:]]*/, "", original)
                    gsub(/^"|"$/, "", original)
                    print original
                    exit
                }
            }
            if (indent_level == 0 && original ~ /^[^:]+:/) {
                found_section = 0
            }
        }
    }
' "$CONFIG_FILE"