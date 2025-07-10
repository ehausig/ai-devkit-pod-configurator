#!/bin/bash
# Persona management hook logic
# Called by hook-framework.sh

# Extract command
command=$(get_command)

# Check if this is a persona initialization command
if [[ "$command" =~ persona-([^-]+)-init\.sh ]]; then
    persona="${BASH_REMATCH[1]^^}"  # Convert to uppercase
    log_hook_event "PERSONA:SWITCH" "Switching to $persona persona"
    
    # Log the transition context
    case "$persona" in
        ARCHITECT)
            log_hook_event "PERSONA:CONTEXT" "Starting system design phase"
            ;;
        DEVELOPER)
            log_hook_event "PERSONA:CONTEXT" "Starting implementation phase"
            ;;
        QA)
            log_hook_event "PERSONA:CONTEXT" "Starting testing phase"
            ;;
        REVIEWER)
            log_hook_event "PERSONA:CONTEXT" "Starting code review phase"
            ;;
        MERGER)
            log_hook_event "PERSONA:CONTEXT" "Starting integration phase"
            ;;
    esac
fi

# Check for handoff commands
if [[ "$command" =~ persona-([^-]+)-handoff\.sh ]]; then
    persona="${BASH_REMATCH[1]^^}"
    log_hook_event "PERSONA:HANDOFF" "$persona completing handoff"
fi
