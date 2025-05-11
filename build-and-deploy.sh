#!/bin/bash
set -e

# Configuration
IMAGE_NAME="claude-code"
IMAGE_TAG="latest"
NAMESPACE="claude-code"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Building Claude Code Container for Kubernetes ===${NC}"

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

if ! command -v colima &> /dev/null; then
    echo -e "${RED}Error: colima is not installed or not in PATH${NC}"
    exit 1
fi

# Check if colima and kubernetes are running
if ! colima status &> /dev/null; then
    echo -e "${RED}Error: Colima is not running${NC}"
    echo "Please start Colima with: colima start --kubernetes"
    exit 1
fi

# Check if kubernetes is accessible
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Error: Kubernetes is not accessible${NC}"
    echo "Please make sure Colima started with --kubernetes flag"
    exit 1
fi

echo -e "${GREEN}Colima with Kubernetes is running and accessible${NC}"

# Clean up and redeploy if needed
if [ "$1" == "--clean" ] || [ "$1" == "-c" ]; then
    echo -e "${YELLOW}Cleaning up previous deployment...${NC}"
    kubectl delete deployment claude-code -n ${NAMESPACE} --ignore-not-found=true
    echo -e "${YELLOW}Removing previous Docker image...${NC}"
    docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
fi

# Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

# Load the image into colima's containerd
echo -e "${YELLOW}Loading image into Colima...${NC}"
colima kubernetes load ${IMAGE_NAME}:${IMAGE_TAG}

# Create namespace if it doesn't exist
echo -e "${YELLOW}Creating Kubernetes namespace...${NC}"
kubectl apply -f kubernetes/namespace.yaml

# Apply Kubernetes resources
echo -e "${YELLOW}Applying Kubernetes resources...${NC}"
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/pvc.yaml
kubectl apply -f kubernetes/deployment.yaml

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/claude-code -n ${NAMESPACE}

# Get pod name
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=claude-code -o jsonpath="{.items[0].metadata.name}")

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "Claude Code is now running in container: ${YELLOW}${POD_NAME}${NC}"
echo -e "\nTo connect to the container, run:"
echo -e "${YELLOW}kubectl exec -it -n ${NAMESPACE} ${POD_NAME} -- bash${NC}"
echo -e "\nOnce connected, you can start Claude Code with:"
echo -e "${YELLOW}cd /home/claude/workspace${NC}"
echo -e "${YELLOW}claude${NC}"
