#!/bin/bash
# Test script for buildah-tools: Build → Push → Verify workflow
# This script tests the complete container image build and push workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$HOME/workspace/buildah-test-$$"
IMAGE_NAME="buildah-test"
IMAGE_TAG="v1.0-test"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║     Buildah/Podman Registry Workflow Test                     ║${NC}"
echo -e "${BLUE}║     Tests: Build → Tag → Push → Verify                        ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to cleanup
cleanup() {
    echo -e "\n${YELLOW}Cleaning up test files...${NC}"
    rm -rf "$TEST_DIR"
    podman rmi -f "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    podman rmi -f "${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

# Check prerequisites
echo -e "${BLUE}[1/8] Checking prerequisites...${NC}"
if ! command -v podman &> /dev/null; then
    echo -e "${RED}✗ podman not found${NC}"
    exit 1
fi
if ! command -v buildah &> /dev/null; then
    echo -e "${RED}✗ buildah not found${NC}"
    exit 1
fi
if ! command -v skopeo &> /dev/null; then
    echo -e "${RED}✗ skopeo not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ podman $(podman --version | awk '{print $3}')${NC}"
echo -e "${GREEN}✓ buildah $(buildah --version | awk '{print $3}')${NC}"
echo -e "${GREEN}✓ skopeo $(skopeo --version | awk '{print $3}')${NC}"
echo ""

# Get registry configuration
echo -e "${BLUE}[2/8] Registry configuration...${NC}"
echo ""
echo "This test requires a container registry to push images to."
echo "You can use configure-buildah.sh to set up a registry, or enter details manually."
echo ""
read -p "Do you want to run configure-buildah.sh now? (y/n): " RUN_CONFIGURE

if [[ "$RUN_CONFIGURE" =~ ^[Yy]$ ]]; then
    if command -v configure-buildah.sh &> /dev/null; then
        echo ""
        echo -e "${YELLOW}Running configure-buildah.sh...${NC}"
        echo ""
        configure-buildah.sh
        echo ""
    else
        echo -e "${RED}✗ configure-buildah.sh not found in PATH${NC}"
        exit 1
    fi
fi

# Prompt for registry details
echo ""
echo "Enter the registry URL to test (e.g., registry.example.com:443):"
read -p "Registry URL: " REGISTRY_URL

if [[ -z "$REGISTRY_URL" ]]; then
    echo -e "${RED}✗ Registry URL cannot be empty${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Using registry: ${REGISTRY_URL}${NC}"
echo ""

# Create test application
echo -e "${BLUE}[3/8] Creating test application...${NC}"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

cat > app.py <<'EOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import os, socket, datetime

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        hostname = socket.gethostname()
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        response = f"""
        <html>
        <head><title>Buildah Test Success</title></head>
        <body style="font-family: Arial; padding: 20px; background: #f0f0f0;">
            <div style="background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <h1 style="color: #28a745;">✓ Buildah/Podman Test Successful!</h1>
                <hr>
                <p><strong>Image built with:</strong> AI DevKit + Buildah + Podman</p>
                <p><strong>Hostname:</strong> {hostname}</p>
                <p><strong>Timestamp:</strong> {now}</p>
                <p><strong>Registry:</strong> {os.getenv('REGISTRY_URL', 'N/A')}</p>
                <hr>
                <p style="color: #666;">This container was built inside an AI DevKit pod and pushed to a registry.</p>
            </div>
        </body>
        </html>
        """
        self.wfile.write(response.encode())

print(f"Server starting on port 8080...")
print(f"Registry: {os.getenv('REGISTRY_URL', 'N/A')}")
HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
EOF

cat > Dockerfile <<EOF
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
ENV REGISTRY_URL=${REGISTRY_URL}
EXPOSE 8080
CMD ["python", "app.py"]
EOF

echo -e "${GREEN}✓ Created test application in ${TEST_DIR}${NC}"
echo ""

# Build image
echo -e "${BLUE}[4/8] Building container image...${NC}"
echo ""
START_TIME=$(date +%s)
if podman build -t "${IMAGE_NAME}:${IMAGE_TAG}" .; then
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    echo ""
    echo -e "${GREEN}✓ Image built successfully in ${BUILD_TIME}s${NC}"
else
    echo -e "${RED}✗ Image build failed${NC}"
    exit 1
fi
echo ""

# Verify image
echo -e "${BLUE}[5/8] Verifying built image...${NC}"
if podman images | grep -q "${IMAGE_NAME}.*${IMAGE_TAG}"; then
    SIZE=$(podman images --format "{{.Size}}" "${IMAGE_NAME}:${IMAGE_TAG}")
    echo -e "${GREEN}✓ Image found: ${IMAGE_NAME}:${IMAGE_TAG} (${SIZE})${NC}"
else
    echo -e "${RED}✗ Built image not found${NC}"
    exit 1
fi
echo ""

# Tag for registry
echo -e "${BLUE}[6/8] Tagging image for registry...${NC}"
FULL_IMAGE_NAME="${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
if podman tag "${IMAGE_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}"; then
    echo -e "${GREEN}✓ Tagged as: ${FULL_IMAGE_NAME}${NC}"
else
    echo -e "${RED}✗ Failed to tag image${NC}"
    exit 1
fi
echo ""

# Push to registry
echo -e "${BLUE}[7/8] Pushing image to registry...${NC}"
echo -e "${YELLOW}This may take a moment depending on image size and network speed...${NC}"
echo ""
START_TIME=$(date +%s)
if podman push "${FULL_IMAGE_NAME}"; then
    END_TIME=$(date +%s)
    PUSH_TIME=$((END_TIME - START_TIME))
    echo ""
    echo -e "${GREEN}✓ Image pushed successfully in ${PUSH_TIME}s${NC}"
else
    echo ""
    echo -e "${RED}✗ Failed to push image to registry${NC}"
    echo ""
    echo -e "${YELLOW}Common causes:${NC}"
    echo "  - Registry authentication not configured"
    echo "  - Registry URL incorrect or unreachable"
    echo "  - TLS certificate not trusted"
    echo "  - Network connectivity issues"
    echo ""
    echo -e "${YELLOW}Try running: configure-buildah.sh${NC}"
    exit 1
fi
echo ""

# Verify push with skopeo
echo -e "${BLUE}[8/8] Verifying image in registry...${NC}"
if skopeo inspect "docker://${FULL_IMAGE_NAME}" > /dev/null 2>&1; then
    DIGEST=$(skopeo inspect "docker://${FULL_IMAGE_NAME}" | grep -o '"Digest": *"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Image verified in registry${NC}"
    echo -e "${GREEN}  Digest: ${DIGEST}${NC}"
else
    echo -e "${RED}✗ Failed to verify image in registry${NC}"
    exit 1
fi
echo ""

# Success summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}║                    ✓ ALL TESTS PASSED!                         ║${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  Build time:      ${BUILD_TIME}s"
echo -e "  Push time:       ${PUSH_TIME}s"
echo -e "  Registry:        ${REGISTRY_URL}"
echo -e "  Image:           ${FULL_IMAGE_NAME}"
echo -e "  Image size:      ${SIZE}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Deploy this image to your Kubernetes cluster"
echo "  2. Use 'podman images' to see local images"
echo "  3. Use 'skopeo inspect docker://${FULL_IMAGE_NAME}' to inspect remote image"
echo ""
echo -e "${GREEN}Buildah/Podman is working correctly! 🎉${NC}"
echo ""
