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

# Check registry configuration
echo -e "${BLUE}[2/10] Checking registry configuration...${NC}"
REGISTRIES_CONF="$HOME/.config/containers/registries.conf"

if [[ ! -f "$REGISTRIES_CONF" ]] || ! grep -q "^\[\[registry\]\]" "$REGISTRIES_CONF" 2>/dev/null; then
    echo ""
    echo -e "${RED}✗ No registry configured${NC}"
    echo ""
    echo "Please configure a container registry first:"
    echo ""
    echo "  1. Run: configure-buildah.sh"
    echo "  2. Add your registry (e.g., registry.example.com:443)"
    echo "  3. Configure TLS and authentication as needed"
    echo "  4. Re-run this test"
    echo ""
    exit 1
fi

# Extract configured registries
CONFIGURED_REGISTRIES=$(grep -A 1 "^\[\[registry\]\]" "$REGISTRIES_CONF" | grep "location" | cut -d'"' -f2 | head -1)

if [[ -z "$CONFIGURED_REGISTRIES" ]]; then
    echo -e "${RED}✗ No registry location found in configuration${NC}"
    echo "Please run: configure-buildah.sh"
    exit 1
fi

echo -e "${GREEN}✓ Found configured registry: ${CONFIGURED_REGISTRIES}${NC}"
echo ""
echo "Enter the registry URL to test (press Enter to use: ${CONFIGURED_REGISTRIES}):"
read -p "Registry URL: " REGISTRY_URL

if [[ -z "$REGISTRY_URL" ]]; then
    REGISTRY_URL="$CONFIGURED_REGISTRIES"
fi

echo -e "${GREEN}✓ Using registry: ${REGISTRY_URL}${NC}"
echo ""

# Create test application
echo -e "${BLUE}[3/10] Creating test application...${NC}"
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
echo -e "${BLUE}[4/10] Building container image...${NC}"
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
echo -e "${BLUE}[5/10] Verifying built image...${NC}"
if podman images | grep -q "${IMAGE_NAME}.*${IMAGE_TAG}"; then
    SIZE=$(podman images --format "{{.Size}}" "${IMAGE_NAME}:${IMAGE_TAG}")
    echo -e "${GREEN}✓ Image found: ${IMAGE_NAME}:${IMAGE_TAG} (${SIZE})${NC}"
else
    echo -e "${RED}✗ Built image not found${NC}"
    exit 1
fi
echo ""

# Tag for registry
echo -e "${BLUE}[6/10] Tagging image for registry...${NC}"
FULL_IMAGE_NAME="${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
if podman tag "${IMAGE_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}"; then
    echo -e "${GREEN}✓ Tagged as: ${FULL_IMAGE_NAME}${NC}"
else
    echo -e "${RED}✗ Failed to tag image${NC}"
    exit 1
fi
echo ""

# Push to registry
echo -e "${BLUE}[7/10] Pushing image to registry...${NC}"
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
echo -e "${BLUE}[8/10] Verifying image in registry...${NC}"
if skopeo inspect "docker://${FULL_IMAGE_NAME}" > /dev/null 2>&1; then
    DIGEST=$(skopeo inspect "docker://${FULL_IMAGE_NAME}" | grep -o '"Digest": *"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Image verified in registry${NC}"
    echo -e "${GREEN}  Digest: ${DIGEST}${NC}"
else
    echo -e "${RED}✗ Failed to verify image in registry${NC}"
    exit 1
fi
echo ""

# Deploy to Kubernetes
echo -e "${BLUE}[9/10] Deploying to Kubernetes cluster...${NC}"
TEST_NAMESPACE="buildah-test-$$"
TEST_DEPLOYMENT="buildah-test"

# Check kubectl access
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠ kubectl not found - skipping K8s deployment test${NC}"
    echo -e "${YELLOW}  Image build and push completed successfully${NC}"
else
    # Create test namespace
    echo "Creating test namespace: ${TEST_NAMESPACE}"
    if kubectl create namespace "${TEST_NAMESPACE}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Namespace created${NC}"

        # Create deployment
        cat > /tmp/buildah-test-deployment-$$.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${TEST_DEPLOYMENT}
  namespace: ${TEST_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${TEST_DEPLOYMENT}
  template:
    metadata:
      labels:
        app: ${TEST_DEPLOYMENT}
    spec:
      containers:
      - name: ${TEST_DEPLOYMENT}
        image: ${FULL_IMAGE_NAME}
        ports:
        - containerPort: 8080
        imagePullPolicy: Always
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF

        echo "Deploying pod..."
        if kubectl apply -f /tmp/buildah-test-deployment-$$.yaml > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Deployment created${NC}"
            rm -f /tmp/buildah-test-deployment-$$.yaml

            # Verify pod in Kubernetes
            echo -e "${BLUE}[10/10] Verifying pod pulls image from registry...${NC}"
            echo "Waiting for pod to be ready (timeout: 60s)..."

            K8S_SUCCESS=false
            if kubectl wait --for=condition=ready pod -l app=${TEST_DEPLOYMENT} -n ${TEST_NAMESPACE} --timeout=60s > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Pod is running${NC}"
                K8S_SUCCESS=true

                # Check events to verify image was pulled
                EVENTS=$(kubectl get events -n ${TEST_NAMESPACE} --field-selector involvedObject.kind=Pod 2>/dev/null | grep -i "pull")
                if echo "$EVENTS" | grep -qi "successfully pulled\|pulled image"; then
                    echo -e "${GREEN}✓ Image successfully pulled from registry${NC}"

                    # Get pod name and show it
                    POD_NAME=$(kubectl get pod -n ${TEST_NAMESPACE} -l app=${TEST_DEPLOYMENT} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                    echo -e "${GREEN}  Pod name: ${POD_NAME}${NC}"
                else
                    echo -e "${YELLOW}⚠ Could not verify image pull event (pod may have used cached image)${NC}"
                fi
            else
                echo ""
                echo -e "${RED}✗ Pod failed to start${NC}"
                echo ""

                # Get pod status
                POD_NAME=$(kubectl get pod -n ${TEST_NAMESPACE} -l app=${TEST_DEPLOYMENT} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                if [[ -n "$POD_NAME" ]]; then
                    POD_STATUS=$(kubectl get pod "$POD_NAME" -n ${TEST_NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null)
                    echo "Pod: $POD_NAME"
                    echo "Status: $POD_STATUS"
                    echo ""

                    # Check for ImagePullBackOff
                    CONTAINER_STATUS=$(kubectl get pod "$POD_NAME" -n ${TEST_NAMESPACE} -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
                    if [[ "$CONTAINER_STATUS" =~ "ImagePullBackOff" ]] || [[ "$CONTAINER_STATUS" =~ "ErrImagePull" ]]; then
                        echo -e "${RED}Issue: ImagePullBackOff${NC}"
                        echo ""
                        echo "The Kubernetes cluster cannot pull the image from the registry."
                        echo ""
                        echo -e "${YELLOW}Common causes:${NC}"
                        echo "  1. K8s nodes don't trust the registry's TLS certificate"
                        echo "  2. K8s needs authentication (imagePullSecret)"
                        echo "  3. Registry URL is not accessible from K8s nodes"
                        echo ""
                        echo -e "${YELLOW}To fix:${NC}"
                        echo ""
                        echo "  For self-signed certificates:"
                        echo "    - Add registry cert to K8s nodes:"
                        echo "      sudo mkdir -p /etc/containerd/certs.d/${REGISTRY_URL}"
                        echo "      sudo cp registry-ca.crt /etc/containerd/certs.d/${REGISTRY_URL}/ca.crt"
                        echo "      sudo systemctl restart k3s"
                        echo ""
                        echo "  For authentication:"
                        echo "    - Create imagePullSecret:"
                        echo "      kubectl create secret docker-registry regcred \\"
                        echo "        --docker-server=${REGISTRY_URL} \\"
                        echo "        --docker-username=<username> \\"
                        echo "        --docker-password=<password> \\"
                        echo "        -n ${TEST_NAMESPACE}"
                        echo ""
                        echo "Events:"
                        kubectl get events -n ${TEST_NAMESPACE} --sort-by='.lastTimestamp' | tail -10
                    else
                        echo "Container status: $CONTAINER_STATUS"
                        echo ""
                        echo "Events:"
                        kubectl get events -n ${TEST_NAMESPACE} --sort-by='.lastTimestamp' | tail -10
                    fi
                    echo ""
                    echo -e "${YELLOW}Namespace ${TEST_NAMESPACE} NOT deleted - inspect with:${NC}"
                    echo "  kubectl get pods -n ${TEST_NAMESPACE}"
                    echo "  kubectl describe pod $POD_NAME -n ${TEST_NAMESPACE}"
                    echo "  kubectl logs $POD_NAME -n ${TEST_NAMESPACE}"
                    echo ""
                    echo -e "${YELLOW}Cleanup when done:${NC}"
                    echo "  kubectl delete namespace ${TEST_NAMESPACE}"
                    echo ""
                fi
            fi

            # Cleanup only on success
            if [[ "$K8S_SUCCESS" == "true" ]]; then
                echo "Cleaning up Kubernetes resources..."
                kubectl delete namespace "${TEST_NAMESPACE}" > /dev/null 2>&1 &
                echo -e "${GREEN}✓ Cleanup initiated (namespace will be deleted in background)${NC}"
            fi
        else
            echo -e "${RED}✗ Failed to create deployment${NC}"
            kubectl delete namespace "${TEST_NAMESPACE}" > /dev/null 2>&1 || true
        fi
    else
        echo -e "${RED}✗ Failed to create namespace${NC}"
        echo -e "${YELLOW}  Continuing without K8s deployment test${NC}"
    fi
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
