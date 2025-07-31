#!/bin/bash
# JSON-based journal logging utility for event sourcing
# Usage: journal-log-json.sh <category> <event_type> [primary_id] [options]
# Examples:
#   journal-log-json.sh system project.initialized --name "Hello World" --prompt "PROMPT.md"
#   journal-log-json.sh kanban card.created "CARD-001" --title "Setup project"
#   journal-log-json.sh agent started --card "CARD-001" --context "Beginning work"

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Function to get current ISO timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S+00:00"
}

# Function to detect actor (agent name or system)
detect_actor() {
    # Try multiple methods to detect the actor
    
    # 1. Check if we're in a Claude Code subagent context
    if [ -n "$CLAUDE_AGENT_NAME" ]; then
        echo "$CLAUDE_AGENT_NAME"
        return
    fi
    
    # 2. Check if actor was passed as environment variable
    if [ -n "$ACTOR_NAME" ]; then
        echo "$ACTOR_NAME"
        return
    fi
    
    # 3. Try to detect from current process context
    # Look for agent name in parent process command line
    PARENT_CMD=$(ps -o comm= -p $PPID 2>/dev/null || true)
    case "$PARENT_CMD" in
        *platform-engineer*) echo "platform-engineer"; return ;;
        *feature-developer*) echo "feature-developer"; return ;;
        *qa-engineer*) echo "qa-engineer"; return ;;
        *api-designer*) echo "api-designer"; return ;;
        *database-engineer*) echo "database-engineer"; return ;;
        *security-specialist*) echo "security-specialist"; return ;;
        *performance-engineer*) echo "performance-engineer"; return ;;
        *algorithm-developer*) echo "algorithm-developer"; return ;;
        *integration-specialist*) echo "integration-specialist"; return ;;
        *solution-architect*) echo "solution-architect"; return ;;
        *cloud-architect*) echo "cloud-architect"; return ;;
        *data-architect*) echo "data-architect"; return ;;
    esac
    
    # 4. Default to PM for main thread or system
    if [ -n "$USER" ]; then
        echo "PM"
    else
        echo "system"
    fi
}

# Function to escape JSON strings
json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\//\\\//g; s/\t/\\t/g; s/\n/\\n/g; s/\r/\\r/g'
}

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: journal-log-json.sh <category> <event_type> [primary_id] [options]"
    echo "Categories: system, kanban, agent, test, telemetry"
    exit 1
fi

CATEGORY="$1"
EVENT_TYPE="$2"
shift 2

# Initialize variables
PRIMARY_ID=""
declare -A DATA

# Check if third argument is a primary ID (for kanban cards, etc.)
if [ $# -gt 0 ] && [[ ! "$1" =~ ^-- ]]; then
    PRIMARY_ID="$1"
    shift
fi

# Parse named arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --*)
            KEY="${1#--}"
            shift
            if [ $# -gt 0 ]; then
                VALUE="$1"
                DATA["$KEY"]="$VALUE"
                shift
            fi
            ;;
        *)
            shift
            ;;
    esac
done

# Build JSON event
TIMESTAMP=$(get_timestamp)
ACTOR=$(detect_actor)
FULL_EVENT_TYPE="${CATEGORY}.${EVENT_TYPE}"

# Start building JSON
JSON="{\"timestamp\":\"$TIMESTAMP\",\"event_type\":\"$FULL_EVENT_TYPE\",\"actor\":\"$ACTOR\""

# Add primary ID fields based on category
case "$CATEGORY" in
    kanban)
        if [ -n "$PRIMARY_ID" ]; then
            JSON="$JSON,\"card_id\":\"$PRIMARY_ID\""
        fi
        ;;
    agent)
        # Generate session ID if not provided
        if [ -z "${DATA[session]}" ]; then
            DATA["session"]=$(uuidgen 2>/dev/null || echo "$(date +%s)-$$")
        fi
        JSON="$JSON,\"session_id\":\"${DATA[session]}\""
        unset DATA["session"]
        
        # Add parent session if provided
        if [ -n "${DATA[parent-session]}" ]; then
            JSON="$JSON,\"parent_session_id\":\"${DATA[parent-session]}\""
            unset DATA["parent-session"]
        fi
        ;;
esac

# Add data object if we have any data
if [ ${#DATA[@]} -gt 0 ]; then
    JSON="$JSON,\"data\":{"
    FIRST=true
    for KEY in "${!DATA[@]}"; do
        if [ "$FIRST" = false ]; then
            JSON="$JSON,"
        fi
        FIRST=false
        
        # Handle different value types
        VALUE="${DATA[$KEY]}"
        
        # Check if value is a number
        if [[ "$VALUE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            JSON="$JSON\"$KEY\":$VALUE"
        # Check if value is boolean
        elif [[ "$VALUE" == "true" || "$VALUE" == "false" ]]; then
            JSON="$JSON\"$KEY\":$VALUE"
        # Check if value is null
        elif [[ "$VALUE" == "null" ]]; then
            JSON="$JSON\"$KEY\":null"
        # Otherwise treat as string
        else
            ESCAPED_VALUE=$(json_escape "$VALUE")
            JSON="$JSON\"$KEY\":\"$ESCAPED_VALUE\""
        fi
    done
    JSON="$JSON}"
fi

# Close JSON object
JSON="$JSON}"

# Append to journal
echo "$JSON" >> "$JOURNAL_PATH"

# Return success
exit 0
