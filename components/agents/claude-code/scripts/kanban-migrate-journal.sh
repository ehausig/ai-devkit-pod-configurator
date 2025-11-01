#!/bin/bash
# Migrate existing journal entries to new format
# Usage: kanban-migrate-journal.sh [--dry-run] [--backup]
# Options:
#   --dry-run    Show what would be changed without modifying the journal
#   --backup     Create a backup of the original journal before migration

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"
BACKUP_PATH="$HOME/workspace/JOURNAL.md.backup-$(date +%Y%m%d-%H%M%S)"

# Parse arguments
DRY_RUN=false
CREATE_BACKUP=false

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --backup)
            CREATE_BACKUP=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo "No journal found at $JOURNAL_PATH"
    exit 0
fi

# Create backup if requested
if [ "$CREATE_BACKUP" = true ] && [ "$DRY_RUN" = false ]; then
    cp "$JOURNAL_PATH" "$BACKUP_PATH"
    echo "Created backup at $BACKUP_PATH"
fi

# Function to migrate a single event
migrate_event() {
    local event="$1"
    
    # Parse the event
    local event_type=$(echo "$event" | jq -r '.event_type')
    local timestamp=$(echo "$event" | jq -r '.timestamp')
    local actor=$(echo "$event" | jq -r '.actor')
    local card_id=$(echo "$event" | jq -r '.card_id // empty')
    
    # Map old event types to new format
    case "$event_type" in
        "kanban.card.breakdown.started")
            echo "$event" | jq --arg state "breakdown_started" --arg prev "backlog" '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: $state,
                    previous_state: $prev,
                    assigned_to: .actor
                }
            '
            ;;
        "kanban.card.breakdown.ended")
            echo "$event" | jq --arg state "breakdown_ended" --arg prev "breakdown_started" '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: $state,
                    previous_state: $prev,
                    assigned_to: null
                }
            '
            ;;
        "kanban.card.work.started")
            echo "$event" | jq --arg state "work_started" --arg prev "breakdown_ended" '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: $state,
                    previous_state: $prev,
                    assigned_to: .actor
                }
            '
            ;;
        "kanban.card.work.ended")
            echo "$event" | jq --arg state "work_ended" --arg prev "work_started" '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: $state,
                    previous_state: $prev,
                    assigned_to: null
                }
            '
            ;;
        "kanban.card.validation.started")
            echo "$event" | jq --arg state "validation_started" --arg prev "work_ended" '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: $state,
                    previous_state: $prev,
                    assigned_to: .actor
                }
            '
            ;;
        "kanban.card.validation.ended")
            echo "$event" | jq --arg state "validation_ended" --arg prev "validation_started" '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: $state,
                    previous_state: $prev,
                    assigned_to: null
                }
            '
            ;;
        "kanban.card.completed")
            echo "$event" | jq --arg state "done" --arg prev "validation_ended" '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: $state,
                    previous_state: $prev,
                    assigned_to: null
                }
            '
            ;;
        "kanban.card.created")
            # Enhance card creation with default fields
            echo "$event" | jq '
                if .data.state == null then .data.state = "backlog" else . end |
                if .data.assigned_to == null then .data.assigned_to = null else . end |
                if .data.dependencies == null then .data.dependencies = [] else . end |
                if .data.description == null then .data.description = "" else . end |
                if .data.notes == null then .data.notes = "" else . end
            '
            ;;
        "kanban.card.assigned")
            # Convert assignment to state change preserving current state
            echo "$event" | jq '
                .event_type = "kanban.card.state_changed" |
                .data = {
                    state: "work_started",  # Assume work starts when assigned
                    assigned_to: .data.to,
                    previous_state: "breakdown_ended"
                }
            '
            ;;
        *)
            # Leave other events unchanged
            echo "$event"
            ;;
    esac
}

# Process the journal
if [ "$DRY_RUN" = true ]; then
    echo "=== DRY RUN - Showing changes that would be made ==="
    echo ""
    
    # Count events by type
    echo "Event type changes:"
    cat "$JOURNAL_PATH" | jq -r '.event_type' | sort | uniq -c | sort -nr
    echo ""
    
    echo "Sample migrations:"
    # Show first 5 events that would be migrated
    cat "$JOURNAL_PATH" | head -5 | while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        original_type=$(echo "$line" | jq -r '.event_type')
        migrated=$(migrate_event "$line")
        new_type=$(echo "$migrated" | jq -r '.event_type')
        
        if [ "$original_type" != "$new_type" ]; then
            echo "Original: $original_type"
            echo "New:      $new_type"
            echo "Full migrated event:"
            echo "$migrated" | jq '.'
            echo "---"
        fi
    done
else
    echo "Migrating journal entries..."
    
    # Create temporary file for migrated content
    TEMP_FILE=$(mktemp)
    
    # Process each line
    line_count=0
    migrated_count=0
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        line_count=$((line_count + 1))
        
        # Check if this needs migration
        original_type=$(echo "$line" | jq -r '.event_type' 2>/dev/null || echo "")
        
        if [[ "$original_type" =~ ^kanban\.card\.(breakdown|work|validation|completed|assigned) ]]; then
            migrated_count=$((migrated_count + 1))
            migrate_event "$line" >> "$TEMP_FILE"
        else
            echo "$line" >> "$TEMP_FILE"
        fi
        
        # Show progress every 100 lines
        if [ $((line_count % 100)) -eq 0 ]; then
            echo "Processed $line_count lines..."
        fi
    done < "$JOURNAL_PATH"
    
    # Replace original journal with migrated version
    mv "$TEMP_FILE" "$JOURNAL_PATH"
    
    echo ""
    echo "Migration complete!"
    echo "Total lines processed: $line_count"
    echo "Events migrated: $migrated_count"
    
    if [ "$CREATE_BACKUP" = true ]; then
        echo "Original journal backed up to: $BACKUP_PATH"
    fi
fi

echo ""
echo "Migration summary:"
echo "- Old state transition events → kanban.card.state_changed"
echo "- kanban.card.assigned → kanban.card.state_changed with assigned_to"
echo "- Added default fields to card.created events"
echo ""
echo "The journal is now compatible with the pull-based Kanban system."
