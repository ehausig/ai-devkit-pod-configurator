#!/bin/bash
# Debug script to understand why actor tests are terminating

echo "Debugging actor test issues..."

# Check if actor scripts exist
echo "Checking for actor scripts in /usr/local/bin:"
for actor in merger qa reviewer; do
    if [ -f "/usr/local/bin/${actor}-actor.sh" ]; then
        echo "  ✓ ${actor}-actor.sh exists"
        # Check if it's executable
        if [ -x "/usr/local/bin/${actor}-actor.sh" ]; then
            echo "    - Is executable"
        else
            echo "    - NOT executable"
        fi
        # Check first few lines
        echo "    - First 3 lines:"
        head -3 "/usr/local/bin/${actor}-actor.sh" | sed 's/^/      /'
    else
        echo "  ✗ ${actor}-actor.sh NOT FOUND"
    fi
done

echo ""
echo "Testing source command with sed substitution:"

# Create a test script similar to what the tests do
cat > /tmp/test-source.sh << 'EOF'
#!/bin/bash
echo "Test script loaded"
source es-actor-base.sh
echo "After source"
actor_loop "TEST"
EOF

echo "Original script content:"
cat /tmp/test-source.sh

echo ""
echo "After sed substitution:"
sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' /tmp/test-source.sh

echo ""
echo "Testing if sed output can be sourced:"
# Create mock base
cat > /tmp/test-actor-base.sh << 'EOF'
#!/bin/bash
echo "Mock base loaded"
actor_loop() {
    echo "Mock actor_loop called with: $1"
}
EOF

# Try to source the sed output
if bash -c "source <(sed 's|source es-actor-base.sh|source /tmp/test-actor-base.sh|' /tmp/test-source.sh) 2>&1"; then
    echo "✓ Sourcing with sed substitution works"
else
    echo "✗ Sourcing with sed substitution FAILED"
fi

# Cleanup
rm -f /tmp/test-source.sh /tmp/test-actor-base.sh

echo ""
echo "Testing grep -v command:"
# Test the grep -v "^actor_loop" pattern
echo -e "#!/bin/bash\nactor_loop TEST\necho hello\nactor_loop()\n{\n  echo test\n}" | grep -v "^actor_loop"
