#!/bin/bash
# Buildah Tools pre-build script
# Signals that security context is needed for rootless container building

# Standard arguments
TEMP_DIR="$1"
SELECTED_IDS="$2"
SELECTED_NAMES="$3"
SELECTED_YAML_FILES="$4"
SCRIPT_DIR="$5"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Configuring deployment for rootless container building...${NC}"

# Create a marker file indicating that security context is required
# This will be checked by generate-dynamic-deployment.sh
mkdir -p "$TEMP_DIR/deployment-patches"

cat > "$TEMP_DIR/deployment-patches/buildah-security-context.yaml" << 'EOF'
# Security context required for buildah/podman rootless container building
# This file is read by generate-dynamic-deployment.sh
securityContext:
  capabilities:
    add:
      - SYS_ADMIN  # Required for user namespaces
      - SETUID     # Required for uid mapping
      - SETGID     # Required for gid mapping
EOF

echo -e "${GREEN}✓ Security context configuration created${NC}"
echo -e "  Rootless container building will be enabled in deployment"
echo -e ""
echo -e "${YELLOW}⚠ IMPORTANT: After deployment, you must manually apply AppArmor annotation${NC}"
echo -e "  See: components/tools/buildah-tools/POST-DEPLOYMENT-MANUAL-STEPS.md"
