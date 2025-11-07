# Buildah Tools - Post-Deployment Manual Steps

## Required: AppArmor Configuration

After deploying the AI DevKit with buildah-tools, you must apply an AppArmor annotation to allow container building operations.

### Apply AppArmor Annotation

Run this command after deployment:

```bash
kubectl patch deployment ai-devkit -n ai-devkit --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1ai-devkit",
    "value": "unconfined"
  }
]'
```

### Why This Is Needed

Buildah requires the ability to perform filesystem remount operations when applying container image layers. By default, AppArmor security policies block these operations, causing this error:

```
remount /, flags: 0x44000: permission denied
```

Setting the AppArmor profile to "unconfined" allows these operations.

### Verify It Works

After applying the annotation, wait for the pod to restart, then test:

```bash
ssh devuser@localhost -p 2222
cd ~/workspace/test-app
cat > Dockerfile <<EOF
FROM alpine:latest
RUN echo "Hello from buildah"
EOF

podman build -t test:latest .
```

The build should complete successfully.

### Security Considerations

Setting AppArmor to unconfined reduces container security isolation. This is acceptable for development environments but should be carefully considered for production use.

### References

- GitHub Issue: https://github.com/containers/buildah/issues/4920
- Red Hat Best Practices: https://developers.redhat.com/blog/2019/08/14/best-practices-for-running-buildah-in-a-container
