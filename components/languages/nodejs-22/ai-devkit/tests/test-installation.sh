#!/bin/bash
# Test npm package installation
set -e

echo "Testing package installation..."

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Initialize a test project
echo "Creating test project..."
npm init -y > /dev/null 2>&1 || {
    echo "❌ Failed to initialize npm project"
    exit 1
}

# Test installing a small package
echo "Installing test package (is-number)..."
npm install is-number > /dev/null 2>&1 || {
    echo "❌ Failed to install test package"
    exit 1
}

# Test that the package works
cat > test.js <<'EOF'
const isNumber = require('is-number');
console.log('Testing is-number:', isNumber(5), isNumber('5'), isNumber('abc'));
if (isNumber(5) && isNumber('5') && !isNumber('abc')) {
    console.log('✅ Package working correctly');
    process.exit(0);
} else {
    console.log('❌ Package not working correctly');
    process.exit(1);
}
EOF

node test.js || {
    echo "❌ Installed package not working"
    exit 1
}

echo "✅ Package installation working"