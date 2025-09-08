#!/bin/bash

# Generate Dynamic Kubernetes Deployment
# This script generates a deployment.yaml with init container for file setup

generate_dynamic_kubernetes_deployment() {
    local output_file="$1"
    local manifest_file="${2:-}"  # Optional manifest file to detect needed mounts
    
    # Detect which root-level files need mounting
    local need_npmrc=false
    if [[ -f "$manifest_file" ]]; then
        if grep -q '|/home/devuser/\.npmrc|' "$manifest_file" 2>/dev/null; then
            need_npmrc=true
        fi
    fi
    
    # Start with the deployment header including init container
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
      initContainers:
      # Init container to set up configuration files
      - name: setup-configs
        image: alpine:latest
        command: ["/bin/sh", "/scripts/init-copy.sh"]
        volumeMounts:
        - name: config-data
          mountPath: /config-data
        - name: init-home
          mountPath: /home/devuser
        - name: scripts
          mountPath: /scripts
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "50m"
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
        # Shared volumes with init container for configuration files
        - name: init-home
          mountPath: /home/devuser/.config
          subPath: .config
        - name: init-home
          mountPath: /home/devuser/.ai-devkit
          subPath: .ai-devkit
EOF
    
    # Add .npmrc mount only if needed
    if [[ "$need_npmrc" == "true" ]]; then
        cat >> "$output_file" << 'EOF'
        # Mount npmrc file (Node.js component selected)
        - name: init-home
          mountPath: /home/devuser/.npmrc
          subPath: .npmrc
EOF
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
      # Single volume for init container to write to home directory
      - name: init-home
        emptyDir: {}
      # ConfigMap with all component files
      - name: config-data
        configMap:
          name: component-configs
          defaultMode: 0644
      # Init container script
      - name: scripts
        configMap:
          name: init-scripts
          defaultMode: 0755
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