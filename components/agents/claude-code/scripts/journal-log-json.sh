#!/bin/bash
# JSON-based journal logging utility for event sourcing
# Usage: journal-log-json.sh <category> <event_type> [primary_id] [options]
# Examples:
#   journal-log-json.sh system project.initialized --name "Hello World" --prompt "PROMPT.md"
#   journal-log-json.sh kanban card.created "CARD-001" --title "Setup project" --description "Create basic structure"
#   journal-log-json.sh kanban card.state_changed "CARD-001" --state "work_started" --assigned_to "feature-developer"
#   journal-log-json.sh agent started --card "CARD-001" --context "Beginning work"
# IMPORTANT: Never use backslashes for line continuation - always use single line commands

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Function to get current ISO timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S+00:00"
}

# Function to detect agent (agent name or system)
detect_agent() {
    # First check if set via set-agent-name.sh
    DATA_DIR="/home/devuser/.claude/data"
    AGENT_FILE="$DATA_DIR/current-agent-name"
    if [ -f "$AGENT_FILE" ] && [ -r "$AGENT_FILE" ]; then
        STORED_AGENT=$(cat "$AGENT_FILE" 2>/dev/null)
        if [ -n "$STORED_AGENT" ]; then
            echo "$STORED_AGENT"
            return
        fi
    fi
    
    # Priority order for agent detection:
    
    # 1. Check if we're in a Claude Code subagent context
    # Claude sets specific environment variables when running subagents
    if [ -n "$CLAUDE_AGENT_NAME" ]; then
        echo "$CLAUDE_AGENT_NAME"
        return
    fi
    
    # 2. Check if this is being run by Claude Code's task execution
    # When Claude runs a task/subagent, it may set specific identifiers
    if [ -n "$CLAUDE_TASK_ID" ] || [ -n "$CLAUDE_SUBAGENT" ]; then
        # Try to extract agent name from the task context
        # This would be set by Claude when invoking subagents
        if [ -n "$CLAUDE_SUBAGENT" ]; then
            echo "$CLAUDE_SUBAGENT"
            return
        fi
    fi
    
    # 3. Check parent process command line for agent indicators
    # This helps identify which agent script is calling us
    local parent_cmd=$(ps -o args= -p $PPID 2>/dev/null | head -n1 || true)
    
    # Check if parent command contains agent names
    case "$parent_cmd" in
        *"platform-engineer"*) echo "platform-engineer"; return ;;
        *"feature-developer"*) echo "feature-developer"; return ;;
        *"qa-engineer"*) echo "qa-engineer"; return ;;
        *"api-designer"*) echo "api-designer"; return ;;
        *"database-engineer"*) echo "database-engineer"; return ;;
        *"security-specialist"*) echo "security-specialist"; return ;;
        *"performance-engineer"*) echo "performance-engineer"; return ;;
        *"algorithm-developer"*) echo "algorithm-developer"; return ;;
        *"integration-specialist"*) echo "integration-specialist"; return ;;
        *"solution-architect"*) echo "solution-architect"; return ;;
        *"cloud-architect"*) echo "cloud-architect"; return ;;
        *"data-architect"*) echo "data-architect"; return ;;
        *"requirements-analyst"*) echo "requirements-analyst"; return ;;
    esac
    
    # 4. Check if we're in an agent's working directory
    local cwd=$(pwd)
    case "$cwd" in
        */platform-engineer*) echo "platform-engineer"; return ;;
        */feature-developer*) echo "feature-developer"; return ;;
        */qa-engineer*) echo "qa-engineer"; return ;;
        */api-designer*) echo "api-designer"; return ;;
        */database-engineer*) echo "database-engineer"; return ;;
        */security-specialist*) echo "security-specialist"; return ;;
        */performance-engineer*) echo "performance-engineer"; return ;;
        */algorithm-developer*) echo "algorithm-developer"; return ;;
        */integration-specialist*) echo "integration-specialist"; return ;;
        */solution-architect*) echo "solution-architect"; return ;;
        */cloud-architect*) echo "cloud-architect"; return ;;
        */data-architect*) echo "data-architect"; return ;;
    esac
    
    # 5. Check process tree for Claude Code agent indicators
    # Walk up the process tree to find agent context
    local current_pid=$PPID
    local max_depth=5
    local depth=0
    
    while [ $depth -lt $max_depth ] && [ $current_pid -gt 1 ]; do
        local proc_cmd=$(ps -o args= -p $current_pid 2>/dev/null | head -n1 || true)
        
        # Check for agent patterns in the process tree
        for agent in platform-engineer feature-developer qa-engineer api-designer \
                    database-engineer security-specialist performance-engineer \
                    algorithm-developer integration-specialist solution-architect \
                    cloud-architect data-architect; do
            if [[ "$proc_cmd" == *"$agent"* ]]; then
                echo "$agent"
                return
            fi
        done
        
        # Move up the process tree
        current_pid=$(ps -o ppid= -p $current_pid 2>/dev/null | tr -d ' ' || echo "1")
        depth=$((depth + 1))
    done
    
    # 6. Default to product-manager for main thread
    echo "product-manager"
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
AGENT=$(detect_agent)
FULL_EVENT_TYPE="${CATEGORY}.${EVENT_TYPE}"

# Log agent activity events when agent changes
if [ "$CATEGORY" = "agent" ] && [ "$EVENT_TYPE" = "started" ]; then
    # Log agent activation
    ACTIVATION_EVENT="{\"timestamp\":\"$TIMESTAMP\",\"event_type\":\"agent.activated\",\"agent\":\"$AGENT\",\"data\":{}}"
    echo "$ACTIVATION_EVENT" >> "$JOURNAL_PATH"
elif [ "$CATEGORY" = "kanban" ] && [ "$EVENT_TYPE" = "card.created" ]; then
    # Also activate product-manager when creating cards
    if [ "$AGENT" = "product-manager" ]; then
        ACTIVATION_EVENT="{\"timestamp\":\"$TIMESTAMP\",\"event_type\":\"agent.activated\",\"agent\":\"$AGENT\",\"data\":{}}"
        echo "$ACTIVATION_EVENT" >> "$JOURNAL_PATH"
    fi
fi

# Handle backward compatibility for old kanban event types
# Map old event types to new state_changed events
case "$FULL_EVENT_TYPE" in
    "kanban.card.breakdown.started")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="breakdown_started"
        DATA["previous_state"]="backlog"
        ;;
    "kanban.card.breakdown.ended")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="breakdown_ended"
        DATA["previous_state"]="breakdown_started"
        ;;
    "kanban.card.work.started")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="work_started"
        DATA["previous_state"]="breakdown_ended"
        ;;
    "kanban.card.work.ended")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="work_ended"
        DATA["previous_state"]="work_started"
        ;;
    "kanban.card.validation.started")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="validation_started"
        DATA["previous_state"]="work_ended"
        ;;
    "kanban.card.validation.ended")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="validation_ended"
        DATA["previous_state"]="validation_started"
        ;;
    "kanban.card.completed")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="done"
        DATA["previous_state"]="validation_ended"
        ;;
    "kanban.card.blocked")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["state"]="blocked"
        DATA["blocked"]=true
        DATA["blocked_reason"]="${DATA[reason]}"
        unset DATA["reason"]
        ;;
    "kanban.card.unblocked")
        FULL_EVENT_TYPE="kanban.card.state_changed"
        DATA["blocked"]=false
        DATA["blocked_reason"]=""
        ;;
esac

# For card.created events, set default values
if [ "$FULL_EVENT_TYPE" = "kanban.card.created" ]; then
    # Set defaults if not provided
    [ -z "${DATA[state]}" ] && DATA["state"]="backlog"
    [ -z "${DATA[dependencies]}" ] && DATA["dependencies"]="[]"
    [ -z "${DATA[description]}" ] && DATA["description"]=""
    [ -z "${DATA[notes]}" ] && DATA["notes"]=""
    # Handle assigned_to separately due to null handling
fi

# For card.state_changed events, auto-determine previous_state if not provided
if [ "$FULL_EVENT_TYPE" = "kanban.card.state_changed" ] && [ -z "${DATA[previous_state]}" ]; then
    # Get current state from journal
    if [ -n "$PRIMARY_ID" ] && [ -f "$JOURNAL_PATH" ]; then
        CURRENT_STATE=$(cat "$JOURNAL_PATH" | jq -s "
            map(select(.card_id == \"$PRIMARY_ID\")) |
            map(select(.event_type == \"kanban.card.created\" or 
                      .event_type == \"kanban.card.state_changed\" or
                      (.event_type | startswith(\"kanban.card.\") and endswith(\".started\") or endswith(\".ended\")))) |
            last |
            if .event_type == \"kanban.card.created\" then
                .data.state // \"backlog\"
            elif .event_type == \"kanban.card.state_changed\" then
                .data.state
            elif .event_type == \"kanban.card.breakdown.started\" then
                \"breakdown_started\"
            elif .event_type == \"kanban.card.breakdown.ended\" then
                \"breakdown_ended\"
            elif .event_type == \"kanban.card.work.started\" then
                \"work_started\"
            elif .event_type == \"kanban.card.work.ended\" then
                \"work_ended\"
            elif .event_type == \"kanban.card.validation.started\" then
                \"validation_started\"
            elif .event_type == \"kanban.card.validation.ended\" then
                \"validation_ended\"
            elif .event_type == \"kanban.card.completed\" then
                \"done\"
            else
                \"unknown\"
            end
        " 2>/dev/null)
        
        if [ -n "$CURRENT_STATE" ] && [ "$CURRENT_STATE" != "null" ] && [ "$CURRENT_STATE" != "unknown" ]; then
            DATA["previous_state"]="$CURRENT_STATE"
        fi
    fi
fi

# Log agent deactivation when agent completes
if [ "$CATEGORY" = "agent" ] && [ "$EVENT_TYPE" = "completed" ]; then
    # We'll log the deactivation after the completion event
    DEFER_DEACTIVATION=true
elif [ "$CATEGORY" = "system" ] && [ "$EVENT_TYPE" = "project.initialized" ]; then
    # Also activate product-manager when initializing project
    if [ "$AGENT" = "product-manager" ]; then
        ACTIVATION_EVENT="{\"timestamp\":\"$TIMESTAMP\",\"event_type\":\"agent.activated\",\"agent\":\"$AGENT\",\"data\":{}}"
        echo "$ACTIVATION_EVENT" >> "$JOURNAL_PATH"
    fi
fi

# Start building JSON
JSON="{\"timestamp\":\"$TIMESTAMP\",\"event_type\":\"$FULL_EVENT_TYPE\",\"agent\":\"$AGENT\""

# Add primary ID fields based on category
case "$CATEGORY" in
    kanban)
        if [ -n "$PRIMARY_ID" ]; then
            JSON="$JSON,\"card_id\":\"$PRIMARY_ID\""
        fi
        ;;
    agent)
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
        # Check if value is null or "null" string
        elif [[ "$VALUE" == "null" ]] || [[ -z "$VALUE" && "$KEY" == "assigned_to" ]]; then
            JSON="$JSON\"$KEY\":null"
        # Check if value is a JSON array (for dependencies)
        elif [[ "$VALUE" =~ ^\[.*\]$ ]]; then
            JSON="$JSON\"$KEY\":$VALUE"
        # Check if value is a JSON object
        elif [[ "$VALUE" =~ ^\{.*\}$ ]]; then
            JSON="$JSON\"$KEY\":$VALUE"
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

# Handle deferred agent deactivation
if [ "$DEFER_DEACTIVATION" = true ]; then
    DEACTIVATION_EVENT="{\"timestamp\":\"$(get_timestamp)\",\"event_type\":\"agent.deactivated\",\"agent\":\"$AGENT\",\"data\":{}}"
    echo "$DEACTIVATION_EVENT" >> "$JOURNAL_PATH"
fi

# Return success
exit 0
