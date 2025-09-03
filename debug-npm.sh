#!/bin/bash

echo "=== Debugging npm configuration ==="

# Check if build-temp exists
echo "1. Checking .build-temp/staging:"
ls -la .build-temp/staging/generated/NODEJS_20/ 2>/dev/null || echo "  Directory not found"

echo ""
echo "2. Checking manifest for npm entries:"
grep -i npm .build-temp/staging/manifest.txt 2>/dev/null || echo "  No npm entries found"

echo ""
echo "3. Checking ConfigMap for npmrc:"
grep -A5 "npmrc" .build-temp/component-configs-dynamic.yaml 2>/dev/null | head -10 || echo "  No npmrc found in ConfigMap"

echo ""
echo "4. Checking if Node.js component was processed:"
grep -i "nodejs\|npm" build-and-deploy.log 2>/dev/null | grep -v "^#" | tail -10

echo ""
echo "5. Component directory structure:"
ls -la components/languages/nodejs-20/ai-devkit/ 2>/dev/null

echo ""
echo "6. Testing template processor directly:"
source lib/template-processor-bash.sh
component_dir="components/languages/nodejs-20/"
component_id="NODEJS_20"
output_dir="/tmp/test-direct"
mkdir -p "$output_dir"
generate_component_configuration "$component_dir" "$component_id" "$output_dir" 2>&1
echo "Generated files:"
ls -la "$output_dir/"