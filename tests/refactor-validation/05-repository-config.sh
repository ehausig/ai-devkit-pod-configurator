#!/bin/bash
# Test 5: Repository Configuration

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Test 5: Repository Configuration ==="
echo ""

echo "1. Checking repository defaults..."
if [[ -f "$REPO_ROOT/config/repositories.yaml" ]]; then
    echo "✅ PASS: Default repositories.yaml exists"
    # Check PyPI default
    PYPI_URL=$(yq eval '.pypi.repositories[0].url' "$REPO_ROOT/config/repositories.yaml" 2>/dev/null)
    if [[ "$PYPI_URL" == "https://pypi.org/simple" ]]; then
        echo "✅ PASS: PyPI default is correct"
    else
        echo "❌ FAIL: PyPI default is '$PYPI_URL'"
    fi
else
    echo "❌ FAIL: Default repositories.yaml not found"
fi
echo ""

echo "2. Testing repository override..."
# Create a test override
TEST_OVERRIDE="/tmp/test-repo-override.yaml"
cat > "$TEST_OVERRIDE" << 'EOF'
pypi:
  repositories:
    - name: "custom-pypi"
      url: "https://custom.pypi.org/simple"
npm:
  repositories:
    - name: "custom-npm"
      url: "https://custom.npm.org/"
EOF

if [[ -f "$TEST_OVERRIDE" ]]; then
    echo "✅ PASS: Created test override file"
    # Check if repository loader can handle it
    if grep -q "merge_repositories" "$REPO_ROOT"/lib/repository-loader.sh 2>/dev/null; then
        echo "✅ PASS: Repository merger function exists"
    else
        echo "❌ FAIL: Repository merger function not found"
    fi
else
    echo "❌ FAIL: Could not create test override"
fi
rm -f "$TEST_OVERRIDE"
echo ""

echo "3. Checking repository loader functions..."
REPO_FUNCTIONS=("load_default_repositories" "load_override_repositories" "merge_repositories" "resolve_repositories")
for func in "${REPO_FUNCTIONS[@]}"; do
    if grep -q "^$func()" "$REPO_ROOT"/lib/repository-loader.sh 2>/dev/null; then
        echo "✅ PASS: Function $func exists"
    else
        echo "❌ FAIL: Function $func not found"
    fi
done
echo ""

echo "4. Testing credential manager..."
if [[ -f "$REPO_ROOT/lib/credential-manager.sh" ]]; then
    echo "✅ PASS: Credential manager exists"
    if grep -q "resolve_credentials" "$REPO_ROOT/lib/credential-manager.sh"; then
        echo "✅ PASS: Credential resolver function exists"
    else
        echo "❌ FAIL: Credential resolver not found"
    fi
else
    echo "❌ FAIL: Credential manager not found"
fi
echo ""

echo "=== Test 5 Complete ==="