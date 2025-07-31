#!/bin/bash
# Get performance metrics summary
# Usage: metrics-summary.sh [options]
# Options:
#   --metric NAME        Specific metric name
#   --agent AGENT-ID     Filter by agent
#   --period 1h|1d|1w    Time period
#   --aggregation avg|sum|max|min|p95

JOURNAL_PATH="$HOME/workspace/JOURNAL.md"

# Default values
METRIC_NAME=""
AGENT_FILTER=""
PERIOD=""
AGGREGATION="avg"

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --metric)
            METRIC_NAME="$2"
            shift 2
            ;;
        --agent)
            AGENT_FILTER="$2"
            shift 2
            ;;
        --period)
            PERIOD="$2"
            shift 2
            ;;
        --aggregation)
            AGGREGATION="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo "{}"
    exit 0
fi

# Calculate time filter based on period
if [ -n "$PERIOD" ]; then
    case "$PERIOD" in
        1h)
            TIME_AGO=$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%S+00:00" 2>/dev/null || date -u -v-1H +"%Y-%m-%dT%H:%M:%S+00:00")
            ;;
        1d)
            TIME_AGO=$(date -u -d "1 day ago" +"%Y-%m-%dT%H:%M:%S+00:00" 2>/dev/null || date -u -v-1d +"%Y-%m-%dT%H:%M:%S+00:00")
            ;;
        1w)
            TIME_AGO=$(date -u -d "1 week ago" +"%Y-%m-%dT%H:%M:%S+00:00" 2>/dev/null || date -u -v-1w +"%Y-%m-%dT%H:%M:%S+00:00")
            ;;
    esac
fi

# Build jq filter
JQ_FILTER="select(.event_type == \"telemetry.metric\")"

if [ -n "$METRIC_NAME" ]; then
    JQ_FILTER="$JQ_FILTER | select(.data.name == \"$METRIC_NAME\")"
fi

if [ -n "$AGENT_FILTER" ]; then
    JQ_FILTER="$JQ_FILTER | select(.data.labels.agent == \"$AGENT_FILTER\")"
fi

if [ -n "$TIME_AGO" ]; then
    JQ_FILTER="$JQ_FILTER | select(.timestamp > \"$TIME_AGO\")"
fi

# Apply aggregation
case "$AGGREGATION" in
    avg)
        AGG_FUNC="map(.data.value) | add / length"
        ;;
    sum)
        AGG_FUNC="map(.data.value) | add"
        ;;
    max)
        AGG_FUNC="map(.data.value) | max"
        ;;
    min)
        AGG_FUNC="map(.data.value) | min"
        ;;
    p95)
        AGG_FUNC="map(.data.value) | sort | .[length * 0.95 | floor]"
        ;;
    *)
        AGG_FUNC="map(.data.value) | add / length"
        ;;
esac

# Execute query
cat "$JOURNAL_PATH" | jq -s "
map($JQ_FILTER) |
if length > 0 then
    {
        metric: (.[0].data.name // \"unknown\"),
        count: length,
        $AGGREGATION: ($AGG_FUNC),
        unit: (.[0].data.unit // \"unknown\"),
        period: \"${PERIOD:-all_time}\",
        latest_timestamp: (map(.timestamp) | max)
    }
else
    {}
end
"
