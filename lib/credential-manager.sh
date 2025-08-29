#!/bin/bash

# Credential Manager - Handle credential lookup and resolution
# Part of the repository configuration refactoring

set -e

# Configuration file location
CONFIG_FILE="${CONFIG_FILE:-$HOME/.ai-devkit/config.yaml}"

# Function to get credential by ID
get_credential() {
    local cred_id="$1"
    
    if [[ -z "$cred_id" ]]; then
        return 0  # No credential needed (anonymous)
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Config file not found: $CONFIG_FILE" >&2
        return 1
    fi
    
    # Check if credential exists
    local cred_exists=$(yq -r ".credentials[] | select(.id == \"$cred_id\") | .id // \"\"" "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$cred_exists" ]]; then
        echo "ERROR: Credential ID '$cred_id' not found in config" >&2
        return 1
    fi
    
    # Return the full credential object as JSON
    yq -r ".credentials[] | select(.id == \"$cred_id\")" "$CONFIG_FILE" 2>/dev/null | yq -y .
}

# Function to get username for a credential ID
get_credential_username() {
    local cred_id="$1"
    
    if [[ -z "$cred_id" ]]; then
        return 0
    fi
    
    yq -r ".credentials[] | select(.id == \"$cred_id\") | .username // \"\"" "$CONFIG_FILE" 2>/dev/null
}

# Function to get password for a credential ID (handles encryption)
get_credential_password() {
    local cred_id="$1"
    
    if [[ -z "$cred_id" ]]; then
        return 0
    fi
    
    local password=$(yq -r ".credentials[] | select(.id == \"$cred_id\") | .password // \"\"" "$CONFIG_FILE" 2>/dev/null)
    
    # Handle encrypted passwords
    if [[ "$password" == encrypted:* ]]; then
        # Remove the "encrypted:" prefix and decode
        password="${password#encrypted:}"
        echo "$password" | base64 -d 2>/dev/null || echo "$password"
    else
        echo "$password"
    fi
}

# Function to get token for a credential ID (handles encryption)
get_credential_token() {
    local cred_id="$1"
    
    if [[ -z "$cred_id" ]]; then
        return 0
    fi
    
    local token=$(yq -r ".credentials[] | select(.id == \"$cred_id\") | .token // \"\"" "$CONFIG_FILE" 2>/dev/null)
    
    # Handle encrypted tokens
    if [[ "$token" == encrypted:* ]]; then
        # Remove the "encrypted:" prefix and decode
        token="${token#encrypted:}"
        echo "$token" | base64 -d 2>/dev/null || echo "$token"
    else
        echo "$token"
    fi
}

# Function to check if credential exists
credential_exists() {
    local cred_id="$1"
    
    if [[ -z "$cred_id" ]]; then
        return 0  # Empty is valid (anonymous)
    fi
    
    local cred_exists=$(yq -r ".credentials[] | select(.id == \"$cred_id\") | .id // \"\"" "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$cred_exists" ]]; then
        echo "WARNING: Credential '$cred_id' not found in config" >&2
        return 1
    fi
    
    return 0
}

# Function to check if credential has username/password auth
has_basic_auth() {
    local cred_id="$1"
    
    if [[ -z "$cred_id" ]]; then
        return 1
    fi
    
    # Check if credential exists first
    if ! credential_exists "$cred_id"; then
        return 1
    fi
    
    local username=$(get_credential_username "$cred_id")
    local password=$(get_credential_password "$cred_id")
    
    if [[ -n "$username" ]] && [[ -n "$password" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if credential has token auth
has_token_auth() {
    local cred_id="$1"
    
    if [[ -z "$cred_id" ]]; then
        return 1
    fi
    
    # Check if credential exists first
    if ! credential_exists "$cred_id"; then
        return 1
    fi
    
    local token=$(get_credential_token "$cred_id")
    
    if [[ -n "$token" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to format URL with basic auth credentials
add_basic_auth_to_url() {
    local url="$1"
    local cred_id="$2"
    
    if [[ -z "$cred_id" ]]; then
        echo "$url"
        return
    fi
    
    local username=$(get_credential_username "$cred_id")
    local password=$(get_credential_password "$cred_id")
    
    if [[ -n "$username" ]] && [[ -n "$password" ]]; then
        # Insert credentials into URL
        echo "$url" | sed "s|://|://${username}:${password}@|"
    else
        echo "$url"
    fi
}