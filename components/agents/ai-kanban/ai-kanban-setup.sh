#!/bin/bash
# AI Kanban Dashboard pre-build script
# Prepares dashboard files for Docker build injection

# Standard arguments from build system
TEMP_DIR="$1"
SELECTED_IDS="$2"
SELECTED_NAMES="$3"
SELECTED_YAML_FILES="$4"
SCRIPT_DIR="$5"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
log() { echo -e "${YELLOW}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Verify we're in the right directory
AI_KANBAN_DIR="$SCRIPT_DIR/ai-kanban"
[[ ! -d "$AI_KANBAN_DIR" ]] && error "AI Kanban directory not found at $AI_KANBAN_DIR"

log "Setting up AI Kanban Dashboard for build..."

# Copy package.json
cp "$AI_KANBAN_DIR/package.json" "$TEMP_DIR/package.json" || error "Failed to copy package.json"
success "Copied package.json"

# Copy server.js
cp "$AI_KANBAN_DIR/server.js" "$TEMP_DIR/server.js" || error "Failed to copy server.js"
success "Copied server.js"

# Copy lib directory
if [[ -d "$AI_KANBAN_DIR/lib" ]]; then
    cp -r "$AI_KANBAN_DIR/lib" "$TEMP_DIR/lib" || error "Failed to copy lib directory"
    success "Copied lib directory with $(ls -1 "$TEMP_DIR/lib/"*.js 2>/dev/null | wc -l) files"
else
    error "lib directory not found"
fi

# Copy public directory
if [[ -d "$AI_KANBAN_DIR/public" ]]; then
    cp -r "$AI_KANBAN_DIR/public" "$TEMP_DIR/public" || error "Failed to copy public directory"
    
    # Count files in subdirectories
    html_count=$(find "$TEMP_DIR/public" -name "*.html" | wc -l)
    css_count=$(find "$TEMP_DIR/public" -name "*.css" | wc -l)
    js_count=$(find "$TEMP_DIR/public" -name "*.js" | wc -l)
    
    success "Copied public directory ($html_count HTML, $css_count CSS, $js_count JS files)"
else
    error "public directory not found"
fi

# Create a manifest file for reference
cat > "$TEMP_DIR/MANIFEST.txt" << EOF
AI Kanban Dashboard Build Manifest
==================================

Files included:
- package.json - Node.js dependencies
- server.js - Main server application
- lib/ - Server-side modules
  - journal-reader.js - JOURNAL.md file watcher
  - state-builder.js - Kanban state reconstruction
  - metrics.js - Performance metrics calculator
- public/ - Client-side files
  - index.html - Dashboard UI
  - css/dashboard.css - Styling
  - js/dashboard.js - Client-side logic

The dashboard will be installed to /opt/ai-kanban
and can be started with: ai-kanban-start.sh

Port: 3000
URL: http://localhost:3000
EOF

success "Created manifest file"

# Verify all critical files exist
critical_files=(
    "$TEMP_DIR/package.json"
    "$TEMP_DIR/server.js"
    "$TEMP_DIR/lib/journal-reader.js"
    "$TEMP_DIR/lib/state-builder.js"
    "$TEMP_DIR/lib/metrics.js"
    "$TEMP_DIR/public/index.html"
    "$TEMP_DIR/public/css/dashboard.css"
    "$TEMP_DIR/public/js/dashboard.js"
)

log "Verifying critical files..."
for file in "${critical_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        error "Critical file missing: $file"
    fi
done
success "All critical files present"

# Create a simple health check script
cat > "$TEMP_DIR/health-check.js" << 'EOF'
// Simple health check for AI Kanban Dashboard
const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/state',
  method: 'GET',
  timeout: 5000
};

const req = http.request(options, (res) => {
  if (res.statusCode === 200) {
    console.log('AI Kanban Dashboard is healthy');
    process.exit(0);
  } else {
    console.log('AI Kanban Dashboard returned status:', res.statusCode);
    process.exit(1);
  }
});

req.on('error', (err) => {
  console.error('AI Kanban Dashboard health check failed:', err.message);
  process.exit(1);
});

req.on('timeout', () => {
  console.error('AI Kanban Dashboard health check timed out');
  req.destroy();
  process.exit(1);
});

req.end();
EOF

success "Created health check script"

log "AI Kanban Dashboard setup completed successfully!"
info "Total files prepared: $(find "$TEMP_DIR" -type f | wc -l)"
info "Total size: $(du -sh "$TEMP_DIR" | cut -f1)"

# Display build info
echo ""
echo "Build information:"
echo "- Node.js dashboard application"
echo "- Real-time WebSocket updates"
echo "- Monitors: /home/devuser/workspace/JOURNAL.md"
echo "- Provides: Kanban board visualization"
echo "- Access: http://localhost:3000"
