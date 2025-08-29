#!/bin/bash

# Generate Dynamic Kubernetes Deployment
# This script generates a deployment.yaml with dynamic volume mounts
# based on component metadata using the new template system

# Source volume mount manager for dynamic volume generation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/volume-mount-manager.sh"

generate_dynamic_kubernetes_deployment() {
    local volume_mounts_file="$1"
    local output_file="$2"
    
    # Start with the deployment header
    cat > "$output_file" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-devkit
  namespace: ai-devkit
  labels:
    app: ai-devkit
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-devkit
  template:
    metadata:
      labels:
        app: ai-devkit
      annotations:
        kubectl.kubernetes.io/default-container: ai-devkit
    spec:
      containers:
      # Main AI DevKit container
      - name: ai-devkit
        image: ai-devkit:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 22
          name: ssh
        volumeMounts:
        - name: config-volume
          mountPath: /home/devuser/.config/ai-devkit
        - name: workspace-volume
          mountPath: /home/devuser/workspace
        # SSH host keys mount
        - name: ssh-host-keys
          mountPath: /etc/ssh/mounted_keys
          readOnly: true
        # Git configuration mounts (optional - from secret)
        - name: git-config
          mountPath: /tmp/git-mounted/.gitconfig
          subPath: gitconfig
          readOnly: true
        - name: git-credentials
          mountPath: /tmp/git-mounted/.git-credentials
          subPath: git-credentials
          readOnly: true
        - name: gh-hosts
          mountPath: /tmp/git-mounted/gh-hosts.yml
          subPath: gh-hosts
          readOnly: true
EOF
    
    # Add component-specific volume mounts dynamically
    if [[ -f "$volume_mounts_file" ]] && [[ -s "$volume_mounts_file" ]]; then
        echo "        # Dynamic component volume mounts" >> "$output_file"
        
        # Generate volume mounts using the new system
        local mount_specs=$(cat "$volume_mounts_file" 2>/dev/null || true)
        if [[ -n "$mount_specs" ]]; then
            generate_deployment_volume_mounts "$mount_specs" >> "$output_file"
        fi
    fi
    
    # Continue with environment variables and resources
    cat >> "$output_file" << 'EOF'
        env:
        - name: NODE_OPTIONS
          value: "--max-old-space-size=3072"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "5Gi"
            cpu: "4000m"
      
      # Filebrowser sidecar for easy file management
      - name: filebrowser
        image: filebrowser/filebrowser:latest
        ports:
        - containerPort: 8090
          name: filebrowser
        volumeMounts:
        - name: workspace-volume
          mountPath: /srv
        - name: filebrowser-config
          mountPath: /config
        - name: filebrowser-db
          mountPath: /database
        env:
        - name: FB_DATABASE
          value: /database/filebrowser.db
        - name: FB_CONFIG
          value: /config/settings.json
        - name: FB_ROOT
          value: /srv
        - name: FB_LOG
          value: stdout
        - name: FB_PORT
          value: "8090"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      
      volumes:
      - name: config-volume
        persistentVolumeClaim:
          claimName: ai-devkit-config-pvc
      - name: workspace-volume
        persistentVolumeClaim:
          claimName: ai-devkit-workspace-pvc
      - name: filebrowser-config
        configMap:
          name: filebrowser-config
      - name: filebrowser-db
        emptyDir: {}
      # SSH host keys volume
      - name: ssh-host-keys
        secret:
          secretName: ssh-host-keys
          defaultMode: 0600
          optional: false
      # Git configuration volumes (from secret - all optional)
      - name: git-config
        secret:
          secretName: git-config
          items:
          - key: gitconfig
            path: gitconfig
          defaultMode: 0600
          optional: true
      - name: git-credentials
        secret:
          secretName: git-config
          items:
          - key: git-credentials
            path: git-credentials
          defaultMode: 0600
          optional: true
      - name: gh-hosts
        secret:
          secretName: git-config
          items:
          - key: gh-hosts
            path: gh-hosts
          defaultMode: 0600
          optional: true
EOF
    
    # Add dynamic component volume definitions
    if [[ -f "$volume_mounts_file" ]] && [[ -s "$volume_mounts_file" ]]; then
        echo "      # Dynamic component volumes" >> "$output_file"
        
        # Generate volume definitions using the new system
        local mount_specs=$(cat "$volume_mounts_file" 2>/dev/null || true)
        if [[ -n "$mount_specs" ]]; then
            generate_deployment_volumes "$mount_specs" >> "$output_file"
        fi
    fi
    
    # Add the service definition
    cat >> "$output_file" << 'EOF'
---
# Service to expose Filebrowser and SSH
apiVersion: v1
kind: Service
metadata:
  name: ai-devkit
  namespace: ai-devkit
spec:
  selector:
    app: ai-devkit
  ports:
  - name: ssh
    port: 22
    targetPort: 22
  - name: filebrowser
    port: 8090
    targetPort: 8090
  type: ClusterIP
---
# ConfigMap for Filebrowser settings
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebrowser-config
  namespace: ai-devkit
data:
  settings.json: |
    {
      "port": 8090,
      "baseURL": "",
      "address": "0.0.0.0",
      "log": "stdout",
      "database": "/database/filebrowser.db",
      "root": "/srv",
      "username": "admin",
      "password": "admin",
      "branding": {
        "name": "AI DevKit Workspace",
        "disableExternal": false,
        "color": "#2979ff"
      },
      "authMethod": "password",
      "commands": {
        "after_save": [],
        "before_save": []
      },
      "shell": ["/bin/bash", "-c"],
      "allowEdit": true,
      "allowNew": true,
      "disablePreviewResize": false,
      "disableExec": false,
      "disableUsedPercentage": false,
      "hideDotfiles": false
    }
EOF
}

# Export the function for use in other scripts
export -f generate_dynamic_kubernetes_deployment