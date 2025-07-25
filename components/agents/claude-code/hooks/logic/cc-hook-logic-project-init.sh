#!/bin/bash
# Project initialization hook logic
# Detects project creation requests and automatically starts the autonomous system

# Ensure functions are available
if ! type -t is_post_tool_use >/dev/null 2>&1; then
    if [ -f "/usr/local/bin/cc-hook-logic-wrapper.sh" ]; then
        source /usr/local/bin/cc-hook-logic-wrapper.sh
    fi
fi

# Only process Write events that might be project initialization
TOOL_NAME=$(extract_json_field "$JSON_INPUT" '.tool_name')
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "MultiEdit" ]; then
    exit 0
fi

# Check if this is a PostToolUse event
if is_post_tool_use; then
    # Get the file path
    file_path=$(get_file_path)
    
    # Only process JOURNAL.md writes
    if [ "$file_path" != "JOURNAL.md" ] && [ "$file_path" != "$HOME/workspace/JOURNAL.md" ] && [ "$file_path" != "~/workspace/JOURNAL.md" ]; then
        exit 0
    fi
    
    # Get the content that was written
    content=$(extract_json_field "$JSON_INPUT" '.tool_input.content')
    
    # Check if content contains project initialization patterns
    if echo "$content" | grep -E -i "create.*project|build.*application|develop.*system|make.*app|initiate.*architect.*persona" >/dev/null 2>&1; then
        echo "Project initialization detected - starting autonomous system" >&2
        
        # Extract project details from content
        PROJECT_NAME=""
        LANGUAGE=""
        
        # Try to extract project name
        if echo "$content" | grep -E -i "hello.*persona.*project" >/dev/null; then
            PROJECT_NAME="hello persona project"
        elif echo "$content" | grep -E -i "\"([^\"]+)\".*project" >/dev/null; then
            PROJECT_NAME=$(echo "$content" | grep -E -io "\"([^\"]+)\".*project" | sed 's/"//g')
        else
            PROJECT_NAME="project"
        fi
        
        # Try to extract language
        if echo "$content" | grep -E -i "python" >/dev/null; then
            LANGUAGE="Python"
        elif echo "$content" | grep -E -i "node|javascript" >/dev/null; then
            LANGUAGE="Node.js"
        elif echo "$content" | grep -E -i "rust" >/dev/null; then
            LANGUAGE="Rust"
        elif echo "$content" | grep -E -i "go|golang" >/dev/null; then
            LANGUAGE="Go"
        fi
        
        # Check if we've already initialized (prevent duplicate initialization)
        if grep -q "TYPE:WORK_ASSIGNED.*TO:ARCHITECT" "$JOURNAL_FILE" 2>/dev/null; then
            echo "Project already initialized - skipping" >&2
            exit 0
        fi
        
        # Start the autonomous system
        (
            # Kill any existing monitor
            pkill -f es-event-monitor.sh 2>/dev/null || true
            
            # Small delay to ensure process is killed
            sleep 1
            
            # Start event monitor
            echo "Starting event monitor..." >&2
            nohup es-event-monitor.sh > /tmp/event-monitor.log 2>&1 &
            MONITOR_PID=$!
            echo "Event monitor started with PID: $MONITOR_PID" >&2
            
            # Wait for monitor to initialize
            sleep 2
            
            # Verify monitor is running
            if ! kill -0 $MONITOR_PID 2>/dev/null; then
                echo "ERROR: Event monitor failed to start!" >&2
                exit 1
            fi
            
            # Generate timestamp for work IDs
            TIMESTAMP=$(date +%s)
            
            # Emit work assignments
            echo "Emitting work assignments to ARCHITECT..." >&2
            
            if [ -n "$LANGUAGE" ]; then
                es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-1|WORK:Create system architecture for ${PROJECT_NAME} in ${LANGUAGE}"
            else
                es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-1|WORK:Create system architecture for ${PROJECT_NAME}"
            fi
            
            es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-2|WORK:Design API specification and interfaces"
            es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-3|WORK:Define data models and schemas"
            es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:${TIMESTAMP}-4|WORK:Create comprehensive testing strategy"
            
            echo "Autonomous system initialized successfully!" >&2
            
            # Log to journal
            echo "$(date -Iseconds) [HOOK:PROJECT_INIT] Detected project request: ${PROJECT_NAME} ${LANGUAGE}" >> "$JOURNAL_FILE"
            echo "$(date -Iseconds) [HOOK:PROJECT_INIT] Started event monitor PID: $MONITOR_PID" >> "$JOURNAL_FILE"
            echo "$(date -Iseconds) [HOOK:PROJECT_INIT] Assigned 4 work items to ARCHITECT" >> "$JOURNAL_FILE"
            
        ) &
        
        # Return immediately so we don't block Claude Code
        echo "Project initialization hook completed" >&2
    fi
fi
