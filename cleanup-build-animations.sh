#!/bin/bash
# cleanup-build-animations.sh

echo "Cleaning up AI DevKit build animations and processes..."

# Find and kill animation processes
echo "Looking for animation processes..."
for file in /tmp/ai-devkit-anim-*; do
    if [[ -f "$file" ]]; then
        pid=$(basename "$file" | sed 's/ai-devkit-anim-//')
        echo "Found animation PID: $pid"
        if kill -0 "$pid" 2>/dev/null; then
            echo "  Killing process $pid"
            kill "$pid" 2>/dev/null
        fi
        rm -f "$file"
    fi
done

# Kill sleep processes that might be part of animations
echo "Killing animation sleep processes..."
pkill -f "sleep 0.1" 2>/dev/null

# Clean up state files
echo "Removing state files..."
rm -f /tmp/ai-devkit-anim-* 2>/dev/null
rm -f /tmp/ai-devkit-frame-* 2>/dev/null

# Kill any hanging kubectl port-forward
echo "Checking for kubectl port-forward processes..."
pkill -f "kubectl.*port-forward.*ai-devkit" 2>/dev/null

# Show any remaining related processes
echo ""
echo "Remaining related processes:"
ps aux | grep -E "(ai-devkit|build-and-deploy)" | grep -v grep

echo ""
echo "Cleanup complete!"
