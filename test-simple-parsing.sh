#!/bin/bash

CONFIG_FILE="$HOME/.ai-devkit/config.yaml"

echo "Testing simple grep/sed parsing"
echo "==============================="
echo ""

# Function to read nested config values
read_config_simple() {
    local key="$1"
    local section=""
    local field=""
    
    # Split the key into section and field
    if [[ "$key" == *"."* ]]; then
        section="${key%%.*}"
        field="${key#*.}"
    else
        # Top-level key
        grep "^${key}:" "$CONFIG_FILE" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//;s/"$//'
        return
    fi
    
    # Read nested value using grep with context
    # First find the section, then look for the field in the next few lines
    local in_section=0
    while IFS= read -r line; do
        # Check if we're entering the target section
        if [[ "$line" =~ ^${section}: ]]; then
            in_section=1
            continue
        fi
        
        # If we're in the section, look for the field
        if [[ $in_section -eq 1 ]]; then
            # Check if line starts with spaces (indicating it's in the section)
            if [[ "$line" =~ ^[[:space:]]+ ]]; then
                # Check if this line has our field
                if [[ "$line" =~ ^[[:space:]]+${field}: ]]; then
                    # Extract the value
                    echo "$line" | sed "s/^[[:space:]]*${field}:[[:space:]]*//" | sed 's/^"//;s/"$//'
                    return
                fi
            else
                # We've left the section (no leading spaces)
                if [[ "$line" =~ ^[^[:space:]] ]] && [[ "$line" =~ : ]]; then
                    in_section=0
                fi
            fi
        fi
    done < "$CONFIG_FILE"
}

echo "container.build_command: '$(read_config_simple container.build_command)'"
echo "container.runtime: '$(read_config_simple container.runtime)'"
echo "container.runtime_import: '$(read_config_simple container.runtime_import)'"
echo ""
echo "nexus.enabled: '$(read_config_simple nexus.enabled)'"
echo "nexus.url: '$(read_config_simple nexus.url)'"