#!/bin/bash

# SSH Port Forwarding Script

# Configuration
REMOTE_HOST="devuser@localhost"
SSH_PORT=2222
LOCAL_PORT=3000
REMOTE_PORT=3000

# Function to start port forwarding
start_tunnel() {
    # Check if tunnel is already running
    if pgrep -f "ssh -fNL $LOCAL_PORT:localhost:$REMOTE_PORT" > /dev/null; then
        echo "Tunnel already running."
        return 1
    fi

    # Start SSH tunnel in background
    ssh -fNL "$LOCAL_PORT:localhost:$REMOTE_PORT" -p "$SSH_PORT" "$REMOTE_HOST"
    
    if [ $? -eq 0 ]; then
        echo "Tunnel established: localhost:$LOCAL_PORT -> $REMOTE_HOST:$REMOTE_PORT"
    else
        echo "Failed to establish tunnel"
        return 1
    fi
}

# Function to stop port forwarding
stop_tunnel() {
    # Find and kill SSH tunnel processes
    pkill -f "ssh -fNL $LOCAL_PORT:localhost:$REMOTE_PORT"
    
    if [ $? -eq 0 ]; then
        echo "Tunnel closed"
    else
        echo "No tunnel found"
    fi
}

# Function to check tunnel status
status_tunnel() {
    if pgrep -f "ssh -fNL $LOCAL_PORT:localhost:$REMOTE_PORT" > /dev/null; then
        echo "Tunnel is running"
    else
        echo "Tunnel is not running"
    fi
}

# Parse arguments
case "$1" in
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    restart)
        stop_tunnel
        start_tunnel
        ;;
    status)
        status_tunnel
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit 0

