#!/bin/bash
# File Mapping Manager for Init Container Architecture
# Manages file staging and manifest generation for init container copying

# Only set strict mode if not being sourced interactively
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

# Process file mappings for a component
process_component_file_mappings() {
    local component_dir="$1"
    local component_id="$2"
    local staging_dir="$3"
    local manifest_file="$4"
    
    local mappings_file="$component_dir/ai-devkit/file-mappings.yaml"
    
    # Skip if no mappings defined
    if [[ ! -f "$mappings_file" ]]; then
        echo "INFO: No file-mappings.yaml for component $component_id" >&2
        return 0
    fi
    
    echo "Processing file mappings for $component_id..." >&2
    
    # Get the number of file mappings (handle both yq versions)
    local file_count
    # Check if yq is Python-based (kislyuk) by checking if yq script starts with python shebang
    local yq_path=$(command -v yq 2>/dev/null)
    if [[ -n "$yq_path" ]] && head -1 "$yq_path" 2>/dev/null | grep -q "python"; then
        # kislyuk/yq (Python-based) - uses jq syntax, reads from stdin
        file_count=$(cat "$mappings_file" | yq '.files | length' 2>/dev/null || echo "0")
    else
        # mikefarah/yq (Go-based) - uses eval syntax
        file_count=$(yq eval '.files | length' "$mappings_file" 2>/dev/null || echo "0")
    fi
    
    if [[ "$file_count" == "0" ]] || [[ "$file_count" == "null" ]]; then
        echo "INFO: No files defined in mappings for $component_id" >&2
        return 0
    fi
    
    # Process each file mapping
    for (( i=0; i<file_count; i++ )); do
        local source dest mode file_type
        local yq_path=$(command -v yq 2>/dev/null)
        if [[ -n "$yq_path" ]] && head -1 "$yq_path" 2>/dev/null | grep -q "python"; then
            # kislyuk/yq - reads from stdin
            source=$(cat "$mappings_file" | yq -r ".files[$i].source" 2>/dev/null)
            dest=$(cat "$mappings_file" | yq -r ".files[$i].dest" 2>/dev/null)
            mode=$(cat "$mappings_file" | yq -r ".files[$i].mode // \"0644\"" 2>/dev/null)
            file_type=$(cat "$mappings_file" | yq -r ".files[$i].type // \"file\"" 2>/dev/null)
        else
            # mikefarah/yq
            source=$(yq eval ".files[$i].source" "$mappings_file" 2>/dev/null)
            dest=$(yq eval ".files[$i].dest" "$mappings_file" 2>/dev/null)
            mode=$(yq eval ".files[$i].mode // \"0644\"" "$mappings_file" 2>/dev/null)
            file_type=$(yq eval ".files[$i].type // \"file\"" "$mappings_file" 2>/dev/null)
        fi
        
        # Skip if required fields are missing
        if [[ "$source" == "null" ]] || [[ "$dest" == "null" ]]; then
            echo "WARNING: Skipping invalid mapping at index $i for $component_id" >&2
            continue
        fi
        
        # Determine source path based on type
        local source_path=""
        if [[ "$source" == generated/* ]]; then
            # Generated file from template processing
            local filename="${source#generated/}"
            # The actual generated files are in staging_dir/generated/component_id/
            source_path="$staging_dir/generated/$component_id/$filename"
        elif [[ "$source" == static/* ]]; then
            # Static file from component directory
            local static_path="${source#static/}"
            source_path="$component_dir/ai-devkit/static/$static_path"
        elif [[ "$source" == tests/* ]]; then
            # Test file
            local test_file="${source#tests/}"
            source_path="$component_dir/ai-devkit/tests/$test_file"
        else
            # Assume it's a relative path in the component directory
            source_path="$component_dir/ai-devkit/$source"
        fi
        
        # Stage the file if it exists
        if [[ -f "$source_path" ]]; then
            stage_file_for_init "$source_path" "$source" "$staging_dir" "$component_id"
            
            # Add entry to manifest
            # Format: source|destination|mode|owner
            echo "${source}|${dest}|${mode}|devuser" >> "$manifest_file"
        elif [[ -d "$source_path" ]]; then
            stage_directory_for_init "$source_path" "$source" "$staging_dir" "$component_id"
            echo "${source}|${dest}|${mode}|devuser" >> "$manifest_file"
        else
            echo "WARNING: Source file not found: $source_path for $component_id" >&2
        fi
    done
    
    return 0
}

# Stage a file for init container
stage_file_for_init() {
    local source_file="$1"
    local relative_dest="$2"  # Relative path in staging
    local staging_dir="$3"
    local component_id="$4"
    
    # Create staging path
    local stage_path="$staging_dir/$relative_dest"
    local stage_dir=$(dirname "$stage_path")
    
    mkdir -p "$stage_dir"
    cp "$source_file" "$stage_path"
    
    # Preserve execute permissions if set
    if [[ -x "$source_file" ]]; then
        chmod +x "$stage_path"
    fi
    
    echo "  Staged: $relative_dest" >&2
}

# Stage a directory for init container
stage_directory_for_init() {
    local source_dir="$1"
    local relative_dest="$2"
    local staging_dir="$3"
    local component_id="$4"
    
    local stage_path="$staging_dir/$relative_dest"
    
    mkdir -p "$stage_path"
    cp -r "$source_dir"/* "$stage_path/" 2>/dev/null || true
    
    echo "  Staged directory: $relative_dest" >&2
}

# Process static files from component
process_component_static_files() {
    local component_dir="$1"
    local component_id="$2"
    local staging_dir="$3"
    local manifest_file="$4"
    
    local static_dir="$component_dir/ai-devkit/static"
    
    if [[ ! -d "$static_dir" ]]; then
        return 0
    fi
    
    echo "Processing static files for $component_id..." >&2
    
    # Find all files in static directory and stage them
    while IFS= read -r -d '' file; do
        # Get relative path from static directory
        local rel_path="${file#$static_dir/}"
        
        # Stage to static/component_id/path
        local stage_dest="static/$component_id/$rel_path"
        local stage_path="$staging_dir/$stage_dest"
        local stage_dir=$(dirname "$stage_path")
        
        mkdir -p "$stage_dir"
        cp "$file" "$stage_path"
        
        # Preserve permissions
        local mode=$(stat -c %a "$file" 2>/dev/null || echo "0644")
        
        # Add to manifest - destination mirrors the structure under static/
        # e.g., static/home/devuser/.pypirc -> /home/devuser/.pypirc
        echo "${stage_dest}|/${rel_path}|0${mode}|devuser" >> "$manifest_file"
        
        echo "  Staged static: $rel_path" >&2
    done < <(find "$static_dir" -type f -print0 2>/dev/null)
}

# Process test files with proper prefixing
process_component_tests() {
    local component_dir="$1"
    local component_id="$2"
    local staging_dir="$3"
    local manifest_file="$4"
    
    local test_dir="$component_dir/ai-devkit/tests"
    
    if [[ ! -d "$test_dir" ]]; then
        return 0
    fi
    
    echo "Processing tests for $component_id..." >&2
    
    # Sanitize component ID for use in filenames
    local sanitized_id=$(echo "$component_id" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    
    # Stage test files with component prefix
    local test_staging="$staging_dir/tests/$component_id"
    mkdir -p "$test_staging"
    
    for file in "$test_dir"/*; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file")
            local staged_name="${sanitized_id}-${basename}"
            
            cp "$file" "$test_staging/$staged_name"
            chmod +x "$test_staging/$staged_name"
            
            # Add to manifest
            echo "tests/$component_id/${staged_name}|/home/devuser/.ai-devkit/tests/${staged_name}|0755|devuser" >> "$manifest_file"
            
            echo "  Staged test: $staged_name" >&2
        fi
    done
}

# Create test orchestrator run-all.sh
create_test_orchestrator() {
    local staging_dir="$1"
    local manifest_file="$2"
    
    local orchestrator="$staging_dir/tests/run-all.sh"
    
    cat > "$orchestrator" <<'EOF'
#!/bin/bash
# AI DevKit Component Test Orchestrator
# Runs all component verification tests

set -e

echo "========================================="
echo "AI DevKit Component Verification"
echo "========================================="

FAILED=0
PASSED=0
SKIPPED=0

# Track which components we've tested
declare -A tested_components

# Run all verify.sh scripts
for verify_script in /home/devuser/.ai-devkit/tests/*-verify.sh; do
    if [[ -f "$verify_script" ]]; then
        # Extract component ID from filename
        basename=$(basename "$verify_script")
        component_id="${basename%-verify.sh}"
        
        echo ""
        echo "Testing $component_id..."
        echo "-----------------------------------------"
        
        if bash "$verify_script"; then
            echo "✅ $component_id: PASSED"
            PASSED=$((PASSED + 1))
        else
            echo "❌ $component_id: FAILED"
            FAILED=$((FAILED + 1))
        fi
        
        tested_components["$component_id"]=1
    fi
done

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "✅ Passed:  $PASSED"
echo "❌ Failed:  $FAILED"
echo "⚠️  Skipped: $SKIPPED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "All component tests passed!"
    exit 0
else
    echo "$FAILED component(s) failed verification"
    exit 1
fi
EOF
    
    chmod +x "$orchestrator"
    
    # Add orchestrator to manifest
    echo "tests/run-all.sh|/home/devuser/.ai-devkit/tests/run-all.sh|0755|devuser" >> "$manifest_file"
    
    echo "Created test orchestrator" >&2
}

# Generate ConfigMap data from staging directory
generate_configmap_from_staging() {
    local staging_dir="$1"
    local configmap_file="$2"
    
    echo "Generating ConfigMap from staging directory..." >&2
    
    cat > "$configmap_file" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: component-configs
  namespace: ai-devkit
data:
EOF
    
    # Add manifest file
    echo "  manifest.txt: |" >> "$configmap_file"
    if [[ -f "$staging_dir/manifest.txt" ]]; then
        sed 's/^/    /' "$staging_dir/manifest.txt" >> "$configmap_file"
    fi
    
    # Add all staged files to ConfigMap
    while IFS= read -r -d '' file; do
        # Get relative path from staging dir
        local rel_path="${file#$staging_dir/}"
        
        # Skip manifest.txt (already added)
        if [[ "$rel_path" == "manifest.txt" ]]; then
            continue
        fi
        
        # Create ConfigMap key (replace / with -)
        local key=$(echo "$rel_path" | tr '/' '-')
        
        echo "  $key: |" >> "$configmap_file"
        sed 's/^/    /' "$file" >> "$configmap_file"
        
    done < <(find "$staging_dir" -type f -print0 2>/dev/null | sort -z)
    
    echo "ConfigMap generated with $(find "$staging_dir" -type f | wc -l) files" >&2
}

# Export functions (bash only)
if [[ -n "$BASH_VERSION" ]]; then
    export -f process_component_file_mappings 2>/dev/null || true
    export -f stage_file_for_init 2>/dev/null || true
    export -f stage_directory_for_init 2>/dev/null || true
    export -f process_component_static_files 2>/dev/null || true
    export -f process_component_tests 2>/dev/null || true
    export -f create_test_orchestrator 2>/dev/null || true
    export -f generate_configmap_from_staging 2>/dev/null || true
fi