#!/bin/bash
# Event monitor that watches the journal and activates personas reactively
# This is the core event loop of the autonomous system

JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"
MONITOR_PID_FILE="/tmp/es-event-monitor.pid"
LAST_LINE_FILE="/tmp/es-event-monitor.lastline"
PERSONA_PID_DIR="/tmp/es-personas"

# Create directory for persona PID files
mkdir -p "$PERSONA_PID_DIR"

# Check if already running
if [ -f "$MONITOR_PID_FILE" ]; then
  OLD_PID=$(cat "$MONITOR_PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Event monitor already running with PID $OLD_PID"
    exit 0
  fi
fi

# Store our PID
echo $$ >"$MONITOR_PID_FILE"

# Ensure journal exists
if [ ! -f "$JOURNAL_FILE" ]; then
  echo "# Development Journal" >"$JOURNAL_FILE"
  echo "" >>"$JOURNAL_FILE"
fi

# Emit monitor started event
es-event-emit.sh "MONITOR_STARTED" "PID:$$"

# Initialize last line tracker AFTER emitting our start event
CURRENT_LINE=$(wc -l <"$JOURNAL_FILE")
if [ -f "$LAST_LINE_FILE" ]; then
  LAST_LINE=$(cat "$LAST_LINE_FILE")
  # If this is a fresh start, process all existing events
  if [ "$LAST_LINE" -eq 0 ]; then
    LAST_LINE=0 # Process from beginning
  fi
else
  # No lastline file - process from beginning
  LAST_LINE=0
fi
echo "$CURRENT_LINE" >"$LAST_LINE_FILE"

# Cleanup on exit
cleanup() {
  es-event-emit.sh "MONITOR_STOPPED" "PID:$$"
  rm -f "$MONITOR_PID_FILE"
  exit 0
}
trap cleanup EXIT INT TERM

# Process initial events if starting from beginning
process_initial_events() {
  if [ "$LAST_LINE" -eq 0 ] && [ "$CURRENT_LINE" -gt 2 ]; then
    # Process all existing events
    local line_num=0
    while IFS= read -r line; do
      ((line_num++))
      # Skip header lines and our own MONITOR_STARTED event
      if [ $line_num -le 2 ]; then
        continue
      fi
      if [[ "$line" =~ TYPE:MONITOR_STARTED.*PID:$$ ]]; then
        continue
      fi
      if [[ "$line" =~ \[EVENT\] ]]; then
        process_event "$line"
      fi
    done <"$JOURNAL_FILE"
  fi
}

# Main monitoring loop
monitor_loop() {
  # Process any initial events first
  process_initial_events

  while true; do
    CURRENT_LINE=$(wc -l <"$JOURNAL_FILE")

    if [ $CURRENT_LINE -gt $LAST_LINE ]; then
      # Process new lines
      tail -n +$((LAST_LINE + 1)) "$JOURNAL_FILE" | while IFS= read -r line; do
        # Skip our own MONITOR_STOPPED events to prevent loops
        if [[ "$line" =~ TYPE:MONITOR_STOPPED.*PID:$$ ]]; then
          continue
        fi
        if [[ "$line" =~ \[EVENT\] ]]; then
          process_event "$line"
        fi
      done

      # Update last line
      LAST_LINE=$CURRENT_LINE
      echo "$LAST_LINE" >"$LAST_LINE_FILE"
    fi

    # Small sleep to prevent CPU spinning
    sleep 0.5
  done
}

# Process individual events
process_event() {
  local event="$1"
  local timestamp=$(echo "$event" | cut -d' ' -f1)

  # Extract event type
  if [[ "$event" =~ TYPE:([^|]+) ]]; then
    local event_type="${BASH_REMATCH[1]}"

    case "$event_type" in
    WORK_ASSIGNED)
      handle_work_assigned "$event"
      ;;
    HANDOFF_READY)
      handle_handoff_ready "$event"
      ;;
    HANDOFF_INITIATED)
      handle_handoff_initiated "$event"
      ;;
    PERSONA_IDLE)
      handle_persona_idle "$event"
      ;;
    CYCLE_COMPLETE)
      handle_cycle_complete "$event"
      ;;
    MONITOR_HEARTBEAT)
      handle_monitor_heartbeat "$event"
      ;;
    *)
      # Other events don't require action from monitor
      [ -n "$DEBUG" ] && echo "Monitor: Observed event $event_type"
      ;;
    esac
  fi
}

# Handle work assignment - activate persona if not already active
handle_work_assigned() {
  local event="$1"

  if [[ "$event" =~ TO:([^|]+) ]]; then
    local persona="${BASH_REMATCH[1]}"
    local state=$(es-projection.sh "$persona" "current_state")

    # More thorough check - verify process is truly alive
    if [ "$state" != "ACTIVE" ] || ! is_persona_running "$persona"; then
      [ -n "$DEBUG" ] && echo "Monitor: Activating $persona due to work assignment"
      activate_persona "$persona" "WORK_ASSIGNED"
    else
      [ -n "$DEBUG" ] && echo "Monitor: $persona already active, work will be picked up"
    fi
  fi
}

# Handle handoff ready - ensure next persona gets activated
handle_handoff_ready() {
  local event="$1"

  if [[ "$event" =~ TO:([^|]+) ]]; then
    local next_persona="${BASH_REMATCH[1]}"

    # Give a moment for work assignments to be created
    sleep 1

    # Check if next persona has work
    local pending_count=$(es-projection.sh "$next_persona" "pending_work" | wc -l)
    if [ "$pending_count" -gt 0 ]; then
      [ -n "$DEBUG" ] && echo "Monitor: Handoff to $next_persona with $pending_count work items"
      # Always activate the persona on handoff, regardless of current state
      activate_persona "$next_persona" "HANDOFF"
    fi
  fi
}

# Handle explicit handoff initiation
handle_handoff_initiated() {
  local event="$1"

  if [[ "$event" =~ FROM:([^|]+) ]]; then
    local from_persona="${BASH_REMATCH[1]}"
    [ -n "$DEBUG" ] && echo "Monitor: $from_persona initiating handoff"
    # The persona actor will handle the actual handoff
  fi
}

# Handle persona going idle
handle_persona_idle() {
  local event="$1"

  if [[ "$event" =~ PERSONA:([^|]+) ]]; then
    local persona="${BASH_REMATCH[1]}"
    [ -n "$DEBUG" ] && echo "Monitor: $persona is now idle"

    # Check if there's pending work that wasn't seen
    local pending_count=$(es-projection.sh "$persona" "pending_work" | wc -l)
    if [ "$pending_count" -gt 0 ]; then
      [ -n "$DEBUG" ] && echo "Monitor: Reactivating $persona - found $pending_count pending items"
      activate_persona "$persona" "PENDING_WORK_FOUND"
    fi
  fi
}

# Handle cycle completion
handle_cycle_complete() {
  local event="$1"

  if [[ "$event" =~ FINAL_PERSONA:([^|]+) ]]; then
    local final_persona="${BASH_REMATCH[1]}"
    echo "Development cycle completed by $final_persona"

    # Check for any remaining work across all personas
    for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
      local pending=$(es-projection.sh "$persona" "pending_work" | wc -l)
      if [ "$pending" -gt 0 ]; then
        echo "Found $pending pending items for $persona"
        activate_persona "$persona" "REMAINING_WORK"
      fi
    done
  fi
}

# Handle monitor heartbeat - check all persona processes
handle_monitor_heartbeat() {
  local event="$1"
  
  [ -n "$DEBUG" ] && echo "Monitor: Processing heartbeat - checking all personas"
  
  # Check each persona's PID file and verify process is alive
  for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    local pid_file="$PERSONA_PID_DIR/${persona}.pid"
    if [ -f "$pid_file" ]; then
      local pid=$(cat "$pid_file")
      if ! kill -0 "$pid" 2>/dev/null; then
        [ -n "$DEBUG" ] && echo "Monitor: $persona process $pid is dead, removing PID file"
        rm -f "$pid_file"
      fi
    fi
  done
}

# Check if a persona is already running
is_persona_running() {
  local persona="$1"
  local pid_file="$PERSONA_PID_DIR/${persona}.pid"
  
  # In test mode, be more lenient with process detection
  if [ "$TEST_MODE" = "1" ]; then
    # Only check PID file existence and basic process validity
    if [ -f "$pid_file" ]; then
      local pid=$(cat "$pid_file")
      if kill -0 "$pid" 2>/dev/null; then
        return 0  # Process is running
      fi
      # PID file exists but process is not running - remove stale file
      rm -f "$pid_file"
    fi
    return 1  # Process is not running
  fi
  
  if [ -f "$pid_file" ]; then
    local pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      # Verify it's really our actor process
      local cmdline=$(ps -p "$pid" -o args= 2>/dev/null || true)
      local actor_name="$(echo $persona | tr '[:upper:]' '[:lower:]')-actor.sh"
      if echo "$cmdline" | grep -q "$actor_name"; then
        return 0  # Process is running
      fi
    fi
    # PID file exists but process is not running - remove stale file
    rm -f "$pid_file"
  fi
  
  return 1  # Process is not running
}

# Activate a specific persona
activate_persona() {
  local persona="$1"
  local trigger="$2"
  local actor_name="$(echo $persona | tr '[:upper:]' '[:lower:]')-actor.sh"

  # For test mode, don't check if already running since mock actors need to activate
  if [ "$TEST_MODE" != "1" ]; then
    # Check if persona is already running using our tracking
    if is_persona_running "$persona"; then
      [ -n "$DEBUG" ] && echo "Monitor: $persona already running (tracked)"
      return
    fi
  fi

  # Additional check using pgrep as fallback
  if command -v "$actor_name" >/dev/null 2>&1; then
    # Look for running instances of this specific actor
    local running_pids=$(pgrep -f "bash.*${actor_name}$" 2>/dev/null || true)

    if [ -n "$running_pids" ]; then
      # Check each PID to see if it's really our actor
      for pid in $running_pids; do
        # Get the command line of the process
        local cmdline=$(ps -p $pid -o args= 2>/dev/null || true)
        # Check if this is our actor script (not a test script or other process)
        if echo "$cmdline" | grep -E "${actor_name}$" >/dev/null 2>&1; then
          [ -n "$DEBUG" ] && echo "Monitor: $actor_name already running with PID $pid"
          # Update our tracking
          echo "$pid" > "$PERSONA_PID_DIR/${persona}.pid"
          return
        fi
      done
    fi
  fi

  # Start the actor
  echo "Activating $persona persona (trigger: $trigger)"
  
  # Check if in test mode and pass the flag
  if [ "$TEST_MODE" = "1" ]; then
    TEST_MODE=1 JOURNAL_FILE="$JOURNAL_FILE" nohup "$actor_name" --test-harness >"/tmp/${actor_name}.log" 2>&1 &
  else
    nohup "$actor_name" >"/tmp/${actor_name}.log" 2>&1 &
  fi
  
  local pid=$!
  
  # Store the PID for tracking
  echo "$pid" > "$PERSONA_PID_DIR/${persona}.pid"

  # The actor will emit its own PERSONA_ACTIVATED event
  [ -n "$DEBUG" ] && echo "Monitor: Started $actor_name with PID $pid"
  
  # Small delay to prevent rapid reactivation
  sleep 1
}

# Start monitoring
echo "Event monitor started (PID: $$)"
echo "Monitoring journal: $JOURNAL_FILE"
monitor_loop
