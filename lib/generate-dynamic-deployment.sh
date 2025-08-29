#!/bin/bash

# Generate Dynamic Kubernetes Deployment
# This script generates a deployment.yaml with only the necessary volume mounts
# based on selected components

generate_dynamic_kubernetes_deployment() {
    local config_mounts_file="$1"
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
    
    # Add component-specific mounts only if components were selected
    if [[ -f "$config_mounts_file" ]] && [[ -s "$config_mounts_file" ]]; then
        echo "        # Component-specific configuration mounts" >> "$output_file"
        
        # Read the config mounts and add only necessary ones
        while IFS=':' read -r config_type source_file mount_path; do
            case "$config_type" in
                "pip")
                    cat >> "$output_file" << EOF
        - name: pip-config
          mountPath: /home/devuser/.config/pip/pip.conf
          subPath: pip.conf
EOF
                    ;;
                "npm")
                    cat >> "$output_file" << EOF
        - name: npm-config
          mountPath: /home/devuser/.npmrc
          subPath: npmrc
EOF
                    ;;
                "maven")
                    cat >> "$output_file" << EOF
        - name: maven-settings
          mountPath: /home/devuser/.m2/settings.xml
          subPath: settings.xml
EOF
                    ;;
                "cargo")
                    cat >> "$output_file" << EOF
        - name: cargo-dir
          mountPath: /home/devuser/.cargo
        - name: cargo-config
          mountPath: /home/devuser/.cargo/config.toml
          subPath: cargo-config.toml
EOF
                    ;;
                "sbt")
                    cat >> "$output_file" << EOF
        - name: sbt-repositories
          mountPath: /home/devuser/.sbt/repositories
          subPath: repositories
EOF
                    ;;
                "gradle")
                    cat >> "$output_file" << EOF
        - name: gradle-config
          mountPath: /home/devuser/.gradle/gradle.properties
          subPath: gradle.properties
EOF
                    ;;
                "gem")
                    cat >> "$output_file" << EOF
        - name: gem-config
          mountPath: /home/devuser/.gemrc
          subPath: gemrc
EOF
                    ;;
            esac
        done < <(cat "$config_mounts_file" | tr ' ' '\n')
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
    
    # Add component-specific volume definitions only if needed
    if [[ -f "$config_mounts_file" ]] && [[ -s "$config_mounts_file" ]]; then
        echo "      # Component-specific configuration volumes" >> "$output_file"
        
        # Track which volumes we've already added
        local added_volumes=""
        
        while IFS=':' read -r config_type source_file mount_path; do
            # Skip if we've already added this volume
            if [[ "$added_volumes" == *"$config_type"* ]]; then
                continue
            fi
            added_volumes="$added_volumes $config_type"
            
            case "$config_type" in
                "pip")
                    cat >> "$output_file" << EOF
      - name: pip-config
        configMap:
          name: repository-config
          items:
          - key: pip.conf
            path: pip.conf
          defaultMode: 0644
          optional: true
EOF
                    ;;
                "npm")
                    cat >> "$output_file" << EOF
      - name: npm-config
        configMap:
          name: repository-config
          items:
          - key: npmrc
            path: npmrc
          defaultMode: 0644
          optional: true
EOF
                    ;;
                "cargo")
                    cat >> "$output_file" << EOF
      - name: cargo-dir
        emptyDir: {}
      - name: cargo-config
        configMap:
          name: repository-config
          items:
          - key: cargo-config.toml
            path: cargo-config.toml
          defaultMode: 0644
          optional: true
EOF
                    ;;
                "maven")
                    cat >> "$output_file" << EOF
      - name: maven-settings
        configMap:
          name: repository-config
          items:
          - key: settings.xml
            path: settings.xml
          defaultMode: 0644
          optional: true
EOF
                    ;;
                "sbt")
                    cat >> "$output_file" << EOF
      - name: sbt-repositories
        configMap:
          name: repository-config
          items:
          - key: repositories
            path: repositories
          defaultMode: 0644
          optional: true
EOF
                    ;;
                "gradle")
                    cat >> "$output_file" << EOF
      - name: gradle-config
        configMap:
          name: repository-config
          items:
          - key: gradle.properties
            path: gradle.properties
          defaultMode: 0644
          optional: true
EOF
                    ;;
                "gem")
                    cat >> "$output_file" << EOF
      - name: gem-config
        configMap:
          name: repository-config
          items:
          - key: gemrc
            path: gemrc
          defaultMode: 0644
          optional: true
EOF
                    ;;
            esac
        done < <(cat "$config_mounts_file" | tr ' ' '\n')
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