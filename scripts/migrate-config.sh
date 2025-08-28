#!/bin/bash

# Script to migrate old config.yaml format to new components array format

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo -e "${RED}Error: yq is required but not installed${NC}"
    echo "Please install yq first: pip install yq"
    exit 1
fi

# Default config file location
CONFIG_FILE="${1:-$HOME/.ai-devkit/config.yaml}"
BACKUP_FILE="${CONFIG_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
    echo "Usage: $0 [config-file-path]"
    exit 1
fi

echo -e "${YELLOW}Migrating config file: $CONFIG_FILE${NC}"

# Check if already in new format
if yq -r '.components' "$CONFIG_FILE" 2>/dev/null | grep -q -v "null"; then
    echo -e "${GREEN}Config file is already in the new format${NC}"
    exit 0
fi

# Check if old format exists
if ! yq -r '.component_repos' "$CONFIG_FILE" 2>/dev/null | grep -q -v "null"; then
    echo -e "${YELLOW}No component_repos section found, nothing to migrate${NC}"
    exit 0
fi

# Create backup
echo "Creating backup: $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Create temporary file for new config
TEMP_FILE=$(mktemp)

# Copy all non-component_repos sections
echo -e "${YELLOW}Preserving existing configuration sections...${NC}"
yq -y 'del(.component_repos)' "$CONFIG_FILE" > "$TEMP_FILE"

# Convert component_repos to components array
echo -e "${YELLOW}Converting component_repos to components array...${NC}"

# Extract component IDs
COMPONENT_IDS=$(yq -r '.component_repos | keys[]' "$CONFIG_FILE" 2>/dev/null)

if [[ -z "$COMPONENT_IDS" ]]; then
    echo -e "${YELLOW}No components found in component_repos${NC}"
else
    # Start building components array
    echo "" >> "$TEMP_FILE"
    echo "# Components configuration (migrated from component_repos)" >> "$TEMP_FILE"
    echo "components:" >> "$TEMP_FILE"
    
    while IFS= read -r comp_id; do
        if [[ -z "$comp_id" ]]; then
            continue
        fi
        
        echo "  - id: \"$comp_id\"" >> "$TEMP_FILE"
        echo "    repositories:" >> "$TEMP_FILE"
        
        # Get repositories for this component
        REPO_COUNT=$(yq -r ".component_repos.${comp_id} | length" "$CONFIG_FILE" 2>/dev/null)
        
        for ((i=0; i<$REPO_COUNT; i++)); do
            # Extract repository fields
            NAME=$(yq -r ".component_repos.${comp_id}[$i].name // \"\"" "$CONFIG_FILE")
            URL=$(yq -r ".component_repos.${comp_id}[$i].url // \"\"" "$CONFIG_FILE")
            TYPE=$(yq -r ".component_repos.${comp_id}[$i].type // \"\"" "$CONFIG_FILE")
            AUTH=$(yq -r ".component_repos.${comp_id}[$i].auth // \"inherit\"" "$CONFIG_FILE")
            PRIMARY=$(yq -r ".component_repos.${comp_id}[$i].primary // false" "$CONFIG_FILE")
            
            echo "      - name: \"$NAME\"" >> "$TEMP_FILE"
            echo "        url: \"$URL\"" >> "$TEMP_FILE"
            echo "        type: \"$TYPE\"" >> "$TEMP_FILE"
            echo "        auth: \"$AUTH\"" >> "$TEMP_FILE"
            echo "        primary: $PRIMARY" >> "$TEMP_FILE"
        done
        
        echo -e "${GREEN}  ✓ Migrated $comp_id${NC}"
    done <<< "$COMPONENT_IDS"
fi

# Replace original file with migrated version
mv "$TEMP_FILE" "$CONFIG_FILE"

echo -e "\n${GREEN}Migration complete!${NC}"
echo "Original config backed up to: $BACKUP_FILE"
echo ""
echo "Please review the migrated configuration:"
echo -e "${YELLOW}cat $CONFIG_FILE${NC}"
echo ""
echo "If you need to revert:"
echo -e "${YELLOW}cp $BACKUP_FILE $CONFIG_FILE${NC}"