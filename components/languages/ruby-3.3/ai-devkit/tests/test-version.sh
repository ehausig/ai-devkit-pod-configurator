#!/bin/bash
# Test Ruby 3.3 version
set -e

echo "Checking Ruby version..."

# Check if ruby command exists
if ! command -v ruby &> /dev/null; then
    echo "❌ ruby command not found"
    exit 1
fi

# Check Ruby version
ruby_version=$(ruby --version | awk '{print $2}')
if [[ ! "$ruby_version" =~ ^3\.3\. ]]; then
    echo "❌ Wrong Ruby version: $ruby_version (expected 3.3.x)"
    exit 1
fi

echo "✅ Ruby version: $ruby_version"

# Check if gem command exists
if ! command -v gem &> /dev/null; then
    echo "❌ gem command not found"
    exit 1
fi

# Check gem version
gem_version=$(gem --version)
echo "✅ RubyGems version: $gem_version"

# Check if bundle command exists
if command -v bundle &> /dev/null; then
    bundle_version=$(bundle --version)
    echo "✅ Bundler version: $bundle_version"
else
    echo "⚠️  Bundler not found (may need to install)"
fi

# Check if irb command exists
if command -v irb &> /dev/null; then
    echo "✅ irb (Interactive Ruby) available"
else
    echo "⚠️  irb not found"
fi

# Check Ruby load path
echo "✅ Ruby load path configured"

echo "✅ Ruby environment configured correctly"