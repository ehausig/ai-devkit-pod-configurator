---
description: Initialize a new autonomous development project
---

# Initialize Autonomous Project

Start a new project using the event-driven autonomous development system.

## Usage

When the user requests to create a project (e.g., "create a hello world project in Python"), follow these steps:

```bash
# Ensure journal exists
mkdir -p ~/workspace
if [ ! -f ~/workspace/JOURNAL.md ]; then
    echo "# Development Journal" > ~/workspace/JOURNAL.md
    echo "" >> ~/workspace/JOURNAL.md
    echo "## Events" >> ~/workspace/JOURNAL.md
fi

# Parse the user's request to extract project details
USER_REQUEST="$*"  # Get all arguments as the request

# Default values
PROJECT_NAME="project"
PROJECT_TYPE="application"
LANGUAGE=""

# Try to extract project details from common patterns
if [[ "$USER_REQUEST" =~ (create|build|develop|make)[[:space:]]+[a]?[[:space:]]*(.*)[[:space:]]+(project|app|application|api|tool|system) ]]; then
    PROJECT_NAME="${BASH_REMATCH[2]}"
    PROJECT_TYPE="${BASH_REMATCH[3]}"
elif [[ "$USER_REQUEST" =~ (hello[[:space:]]+world) ]]; then
    PROJECT_NAME="hello world"
    PROJECT_TYPE="application"
elif [[ "$USER_REQUEST" =~ (todo|task)[[:space:]]+(list|app) ]]; then
    PROJECT_NAME="todo list"
    PROJECT_TYPE="application"
fi

# Extract language if mentioned
if [[ "$USER_REQUEST" =~ [[:space:]]in[[:space:]]+(Python|python) ]]; then
    LANGUAGE="Python"
elif [[ "$USER_REQUEST" =~ [[:space:]]in[[:space:]]+(JavaScript|javascript|JS|Node|node) ]]; then
    LANGUAGE="Node.js"
elif [[ "$USER_REQUEST" =~ [[:space:]]in[[:space:]]+(Rust|rust) ]]; then
    LANGUAGE="Rust"
elif [[ "$USER_REQUEST" =~ [[:space:]]in[[:space:]]+(Go|go|golang|Golang) ]]; then
    LANGUAGE="Go"
elif [[ "$USER_REQUEST" =~ [[:space:]]in[[:space:]]+(Java|java) ]]; then
    LANGUAGE="Java"
elif [[ "$USER_REQUEST" =~ [[:space:]]in[[:space:]]+(Ruby|ruby) ]]; then
    LANGUAGE="Ruby"
fi

# Extract specific types
if [[ "$USER_REQUEST" =~ (REST|rest)[[:space:]]+(API|api) ]]; then
    PROJECT_TYPE="REST API"
elif [[ "$USER_REQUEST" =~ (web[[:space:]]+scraper|scraper) ]]; then
    PROJECT_TYPE="web scraper"
elif [[ "$USER_REQUEST" =~ (CLI|cli)[[:space:]]+(tool|app) ]]; then
    PROJECT_TYPE="CLI tool"
elif [[ "$USER_REQUEST" =~ (web[[:space:]]+app|website) ]]; then
    PROJECT_TYPE="web application"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create initial work assignment for ARCHITECT
echo "Initializing autonomous development for: $PROJECT_NAME"
echo ""

# Add work assignment to journal
echo "$TIMESTAMP | WORK_ASSIGNED | ARCHITECT | Design and architect $PROJECT_NAME $PROJECT_TYPE${LANGUAGE:+ in $LANGUAGE}" >> ~/workspace/JOURNAL.md

# Log project initialization
echo "$TIMESTAMP | PROJECT_INIT | SYSTEM | Starting autonomous development: $PROJECT_NAME" >> ~/workspace/JOURNAL.md

echo "✓ Project initialized successfully!"
echo ""
echo "The ARCHITECT persona will now begin designing your system."
echo "Use /show-journal to monitor progress."
echo ""

# Now invoke the architect command
/architect
```

## Examples

For "create a hello world project in Python":
```bash
PROJECT_NAME="hello world"
PROJECT_TYPE="application"
LANGUAGE="Python"
```

For "build a REST API for todo list":
```bash
PROJECT_NAME="todo list"
PROJECT_TYPE="REST API"
LANGUAGE=""  # Will be determined by ARCHITECT
```

For "develop a web scraper":
```bash
PROJECT_NAME="web scraper"
PROJECT_TYPE="tool"
LANGUAGE=""
```

## Notes

- This command parses the user's request and creates the initial work assignment
- The ARCHITECT persona is always the first to be activated
- All subsequent handoffs are handled automatically through the Stop hook
- The journal serves as the persistent event store for the entire process
