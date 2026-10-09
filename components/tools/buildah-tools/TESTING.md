# Testing Buildah Tools Component

This component includes a comprehensive test script that validates the complete container build and registry workflow.

## Quick Test

To run the full registry workflow test:

```bash
# SSH into the AI DevKit pod
ssh devuser@localhost -p 2222

# Run the test script
test-registry-workflow.sh
```

The script will:
1. Check that buildah, podman, and skopeo are installed
2. Optionally run `configure-buildah.sh` to set up registry access
3. Create a test Python web application
4. Build a container image
5. Tag the image for your registry
6. Push the image to the registry
7. Verify the image is accessible in the registry

## What You Need

### Registry Access

You'll need access to a container registry. This can be:
- Internal k3s registry (e.g., `registry.namespace.svc.cluster.local:443`)
- Nexus repository manager
- Docker Hub
- Harbor
- Any OCI-compliant registry

### Registry Configuration

The test script can help you configure registry access:
- **TLS/HTTPS**: The script prompts for CA certificates if needed
- **Authentication**: Supports basic auth, token auth
- **Insecure registries**: Can configure for HTTP registries

## Test Scenarios

### Scenario 1: First-time Setup

```bash
# Run test and configure registry interactively
test-registry-workflow.sh

# When prompted:
# - Answer 'y' to run configure-buildah.sh
# - Follow prompts to add your registry
# - Enter registry URL when asked
```

### Scenario 2: Pre-configured Registry

If you've already run `configure-buildah.sh`:

```bash
# Just run the test
test-registry-workflow.sh

# When prompted:
# - Answer 'n' to skip configure-buildah.sh
# - Enter your registry URL
```

### Scenario 3: Testing Multiple Registries

```bash
# Test first registry
test-registry-workflow.sh
# Enter: registry1.example.com:443

# Test second registry
test-registry-workflow.sh
# Enter: registry2.example.com:443
```

## Expected Output

Successful test output:

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                    ✓ ALL TESTS PASSED!                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

Summary:
  Build time:      12s
  Push time:       8s
  Registry:        registry.example.com:443
  Image:           registry.example.com:443/buildah-test:v1.0-test
  Image size:      152MB

Next steps:
  1. Deploy this image to your Kubernetes cluster
  2. Use 'podman images' to see local images
  3. Use 'skopeo inspect docker://...' to inspect remote image

Buildah/Podman is working correctly! 🎉
```

## Troubleshooting

### "x509: certificate signed by unknown authority"

Your registry uses a self-signed certificate. Run the test with `configure-buildah.sh` and provide the CA certificate when prompted.

### "connection refused"

Registry URL is incorrect or unreachable. Verify:
```bash
# Test connectivity
ping registry.example.com
curl -k https://registry.example.com:443/v2/
```

### "unauthorized: authentication required"

Registry requires authentication. Run `configure-buildah.sh` and configure credentials.

### Build succeeds but push fails

Check registry permissions:
```bash
# Test with skopeo
skopeo inspect docker://registry.example.com:443/test:latest
```

## Manual Test Steps

If you prefer to test manually:

```bash
# 1. Configure registry
configure-buildah.sh

# 2. Create test app
mkdir -p ~/workspace/test-build && cd ~/workspace/test-build
echo 'FROM alpine:latest' > Dockerfile
echo 'CMD ["echo", "test"]' >> Dockerfile

# 3. Build
podman build -t test:v1 .

# 4. Tag
podman tag test:v1 registry.example.com:443/test:v1

# 5. Push
podman push registry.example.com:443/test:v1

# 6. Verify
skopeo inspect docker://registry.example.com:443/test:v1
```

## Component Test Suite

The buildah-tools component includes these tests:
- `test-installation.sh` - Verify binaries are installed
- `test-version.sh` - Check versions meet requirements
- `test-functionality.sh` - Basic build test
- `test-registry-workflow.sh` - **Full end-to-end test** (this script)
- `verify.sh` - Run all tests

To run all tests:
```bash
cd /path/to/components/tools/buildah-tools/ai-devkit/tests
./verify.sh
```

## CI/CD Integration

For automated testing in CI/CD pipelines:

```bash
# Non-interactive test (fails if registry not configured)
export REGISTRY_URL="registry.example.com:443"
export SKIP_CONFIGURE=1
test-registry-workflow.sh
```

## Cleanup

The test script automatically cleans up:
- Test workspace directory
- Test images (both local and tagged for registry)

Pushed images remain in the registry and must be deleted manually if desired:
```bash
# Delete from registry using skopeo
skopeo delete docker://registry.example.com:443/buildah-test:v1.0-test
```
