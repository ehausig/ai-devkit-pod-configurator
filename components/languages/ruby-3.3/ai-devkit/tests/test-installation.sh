#!/bin/bash
# Test Ruby gem installation capability
set -e

echo "Testing Ruby gem installation..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test installing a gem locally (without affecting system)
echo "Testing gem install..."
gem install json --user-install --no-document || {
    echo "❌ Failed to install gem"
    exit 1
}

echo "✅ gem install working"

# Test using the installed gem
ruby -e "require 'json'; puts 'JSON gem working: ' + JSON.generate({test: true})" || {
    echo "❌ Installed gem not working"
    exit 1
}

echo "✅ Installed gem working"

# Test Bundler if available
if command -v bundle &> /dev/null; then
    echo "Testing Bundler..."
    
    # Create a simple Gemfile
    cat > Gemfile << 'EOF'
source 'https://rubygems.org'

gem 'json'
gem 'minitest'
EOF

    # Install gems via Bundle
    bundle install --path .bundle --quiet || {
        echo "❌ Bundle install failed"
        exit 1
    }
    
    echo "✅ Bundle install working"
    
    # Test using bundled gems
    bundle exec ruby -e "require 'json'; puts 'Bundled JSON gem working'" || {
        echo "❌ Bundle exec not working"
        exit 1
    }
    
    echo "✅ Bundle exec working"
else
    echo "⚠️  Bundler not available, installing..."
    gem install bundler --user-install --no-document || {
        echo "❌ Failed to install bundler"
        exit 1
    }
    echo "✅ Bundler installed successfully"
fi

# Test creating and running a simple Ruby script
cat > test_script.rb << 'EOF'
#!/usr/bin/env ruby

puts "Hello from Ruby script!"

# Test basic Ruby features
array = [1, 2, 3, 4, 5]
doubled = array.map { |x| x * 2 }
puts "Array doubled: #{doubled}"

# Test hash
hash = { name: "Ruby", version: "3.3" }
puts "Hash: #{hash}"

puts "Ruby script execution successful"
EOF

echo "Testing Ruby script execution..."
ruby test_script.rb | grep -q "Ruby script execution successful" || {
    echo "❌ Ruby script execution failed"
    exit 1
}

echo "✅ Ruby script execution working"

echo "✅ All Ruby installation tests passed"