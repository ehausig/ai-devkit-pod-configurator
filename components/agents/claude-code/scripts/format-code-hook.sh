#!/bin/bash
# Auto-formatting hook logic
# Called by hook-framework.sh

if is_post_tool_use; then
    file_path=$(get_file_path)
    
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        exit 0
    fi
    
    # Log formatting attempt
    log_hook_event "INFO" "Auto-formatting: $file_path"
    
    # Get file extension
    extension="${file_path##*.}"
    
    # Format based on extension
    case "$extension" in
        py)
            # Python - use black if available
            if command -v black >/dev/null 2>&1; then
                black "$file_path" 2>/dev/null || true
            fi
            ;;
        js|jsx|ts|tsx)
            # JavaScript/TypeScript - use prettier if available
            if command -v prettier >/dev/null 2>&1; then
                prettier --write "$file_path" 2>/dev/null || true
            fi
            ;;
        go)
            # Go - use gofmt
            if command -v gofmt >/dev/null 2>&1; then
                gofmt -w "$file_path" 2>/dev/null || true
            fi
            ;;
        rs)
            # Rust - use rustfmt if available
            if command -v rustfmt >/dev/null 2>&1; then
                rustfmt "$file_path" 2>/dev/null || true
            fi
            ;;
        java)
            # Java - use google-java-format if available
            if command -v google-java-format >/dev/null 2>&1; then
                google-java-format -i "$file_path" 2>/dev/null || true
            fi
            ;;
    esac
fi
