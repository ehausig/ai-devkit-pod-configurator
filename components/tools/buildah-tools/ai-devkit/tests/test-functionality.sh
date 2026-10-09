#!/bin/bash
# Test: Buildah Tools Functionality
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing buildah/podman functionality..."

# Create a temporary directory for test
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Create a simple Dockerfile
cat > Dockerfile << 'EOF'
FROM alpine:latest
RUN echo "Hello from Buildah test!"
CMD ["echo", "Container works!"]
EOF

echo -e "${YELLOW}Building test image with buildah...${NC}"
if buildah bud -t buildah-test:latest . > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} buildah build successful"
else
    echo -e "${RED}✗${NC} buildah build failed"
    exit 1
fi

echo -e "${YELLOW}Verifying image exists...${NC}"
if podman images | grep -q "buildah-test"; then
    echo -e "${GREEN}✓${NC} Image created successfully"
else
    echo -e "${RED}✗${NC} Image not found"
    exit 1
fi

echo -e "${YELLOW}Testing image with podman...${NC}"
if podman run --rm buildah-test:latest 2>&1 | grep -q "Container works"; then
    echo -e "${GREEN}✓${NC} Image runs successfully"
else
    echo -e "${RED}✗${NC} Image execution failed"
    exit 1
fi

echo -e "${YELLOW}Cleaning up test image...${NC}"
podman rmi buildah-test:latest > /dev/null 2>&1

echo -e "${GREEN}Functionality tests passed!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} To test pushing to a registry:"
echo "  1. Run: configure-buildah.sh"
echo "  2. Add your registry configuration"
echo "  3. Build and push: docker build -t registry.example.com/myapp . && docker push registry.example.com/myapp"
