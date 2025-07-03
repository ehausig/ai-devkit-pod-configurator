#!/bin/bash
# Fix script to remove .sh extensions from command calls in persona and hook scripts

echo "Fixing .sh extensions in persona and hook scripts..."

# Define the commands that need fixing
COMMANDS_TO_FIX=(
    "journal-query.sh"
    "journal-log.sh"
    "journal-stats.sh"
    "work-tracker.sh"
    "get-context-window.sh"
)

# Define directories to search
DIRS_TO_FIX=(
    "components/agents/claude-code/personas"
    "components/agents/claude-code/hooks"
    "components/agents/claude-code/scripts"
)

# Counter for changes
total_changes=0

# Function to fix a single file
fix_file() {
    local file="$1"
    local changes=0
    
    # Create a backup
    cp "$file" "${file}.backup"
    
    # Fix each command
    for cmd in "${COMMANDS_TO_FIX[@]}"; do
        # Count occurrences
        count=$(grep -c "$cmd" "$file" || true)
        if [ $count -gt 0 ]; then
            # Remove .sh extension from the command
            sed -i "s/${cmd}/${cmd%.sh}/g" "$file"
            changes=$((changes + count))
            echo "  Fixed $count occurrences of $cmd in $(basename "$file")"
        fi
    done
    
    # If no changes were made, remove the backup
    if [ $changes -eq 0 ]; then
        rm "${file}.backup"
    else
        echo "  Total changes in $(basename "$file"): $changes"
    fi
    
    return $changes
}

# Process each directory
for dir in "${DIRS_TO_FIX[@]}"; do
    if [ -d "$dir" ]; then
        echo ""
        echo "Processing directory: $dir"
        
        # Find all .sh files in the directory
        while IFS= read -r -d '' file; do
            echo "Checking: $file"
            fix_file "$file"
            total_changes=$((total_changes + $?))
        done < <(find "$dir" -name "*.sh" -type f -print0)
    else
        echo "Warning: Directory $dir not found"
    fi
done

echo ""
echo "Total changes made: $total_changes"
echo ""

# Also check if the entrypoint.sh needs fixing
if [ -f "docker/entrypoint.base.sh" ]; then
    echo "Checking docker/entrypoint.base.sh..."
    fix_file "docker/entrypoint.base.sh"
fi

# Check the journal query scripts themselves to ensure they don't call each other with .sh
echo ""
echo "Checking self-references in journal scripts..."
for script in components/agents/claude-code/scripts/*.sh; do
    if [ -f "$script" ]; then
        # Check if any script calls another with .sh
        if grep -q "journal-query.sh\|journal-log.sh\|journal-stats.sh\|work-tracker.sh\|get-context-window.sh" "$script"; then
            echo "Fixing self-references in $(basename "$script")"
            fix_file "$script"
        fi
    fi
done

echo ""
echo "Fix complete! Summary of changes:"
echo "- Removed .sh extensions from command calls"
echo "- Created .backup files for any modified files"
echo ""
echo "Next steps:"
echo "1. Review the changes (diff any .backup file with its original)"
echo "2. Remove .backup files when satisfied: find . -name '*.backup' -delete"
echo "3. Rebuild and redeploy the container"
