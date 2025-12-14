#!/bin/bash
# Custom startup script for Plex Discord integration
# This script starts after the desktop environment has initialized

set -e

echo "========== Custom Startup: Plex Discord Integration =========="

# Ensure HOME is set correctly
HOME=${HOME:-/home/kasm-user}
echo "HOME is set to: $HOME"
echo "Checking for plex services..."
ls -la "$HOME/.local/bin/" 2>/dev/null || echo "Warning: $HOME/.local/bin not accessible"

# Export default Plex configuration if not already set
export IP=${IP:-192.168.50.80}
export PORT=${PORT:-32400}
export PLEX_TOKEN=${PLEX_TOKEN}

# Debug: Show Plex configuration
echo "Plex Configuration:"
echo "  IP: $IP"
echo "  PORT: $PORT"
echo "  PLEX_TOKEN: ${PLEX_TOKEN:-(not set)}"
echo "  PLEX_TOKEN length: ${#PLEX_TOKEN}"

# Function to check if a port is in use
port_in_use() {
    local port=$1
    netstat -tln 2>/dev/null | grep -q ":$port " && return 0 || return 1
}

# Start plex-discord-server on port 8765 (Discord bot + HTTP API server for port 8080)
# NOTE: Port 8765 runs WITHOUT SSL - nginx handles SSL/WSS conversion
if [ -f "$HOME/.local/bin/plex-discord-server" ]; then
    echo "Starting plex-discord-server on port 8765 (unencrypted WS, nginx handles SSL)..."

    # Check if port 8765 is already in use
    if ! port_in_use 8765; then
        # Environment variables already exported above
        echo "Starting with: IP=$IP PORT=$PORT PLEX_TOKEN=${PLEX_TOKEN:-(not set)}"
        cd "$HOME" && python3 "$HOME/.local/bin/plex-discord-server" --port 8765 > /tmp/plex-discord-server-8765.log 2>&1 &
        PLEX_SERVER_PID=$!
        echo "plex-discord-server (port 8765) started with PID: $PLEX_SERVER_PID"

        # Wait a moment for it to start
        sleep 2

        if kill -0 $PLEX_SERVER_PID 2>/dev/null; then
            echo "✓ plex-discord-server (port 8765) is running successfully"
        else
            echo "✗ plex-discord-server (port 8765) failed to start. Check /tmp/plex-discord-server-8765.log"
        fi
    else
        echo "⚠ Port 8765 is already in use, skipping plex-discord-server (port 8765) startup"
    fi
else
    echo "⚠ plex-discord-server not found, skipping startup"
fi

# Start plex-discord-server on port 8764 (Firefox extension - unencrypted WS)
if [ -f "$HOME/.local/bin/plex-discord-server" ]; then
    echo "Starting plex-discord-server on port 8764 (for Firefox extension)..."

    # Check if port 8764 is already in use
    if ! port_in_use 8764; then
        cd "$HOME" && python3 "$HOME/.local/bin/plex-discord-server" --port 8764 > /tmp/plex-discord-server-8764.log 2>&1 &
        PLEX_SERVER_8764_PID=$!
        echo "plex-discord-server (port 8764) started with PID: $PLEX_SERVER_8764_PID"

        # Wait a moment for it to start
        sleep 2

        if kill -0 $PLEX_SERVER_8764_PID 2>/dev/null; then
            echo "✓ plex-discord-server (port 8764) is running successfully"
        else
            echo "✗ plex-discord-server (port 8764) failed to start. Check /tmp/plex-discord-server-8764.log"
        fi
    else
        echo "⚠ Port 8764 is already in use, skipping plex-discord-server (port 8764) startup"
    fi
else
    echo "⚠ plex-discord-server not found, skipping port 8764 startup"
fi

# Start websocket-proxy (SSL/WSS proxy on port 8766) if it exists
if [ -f "$HOME/.local/bin/websocket-proxy" ]; then
    echo "Starting websocket-proxy (SSL proxy on 8766)..."

    # Check if port 8766 is already in use
    if ! port_in_use 8766; then
        cd "$HOME" && python3 "$HOME/.local/bin/websocket-proxy" > /tmp/websocket-proxy.log 2>&1 &
        WEBSOCKET_PROXY_PID=$!
        echo "websocket-proxy started with PID: $WEBSOCKET_PROXY_PID"

        # Wait a moment for it to start
        sleep 2

        if kill -0 $WEBSOCKET_PROXY_PID 2>/dev/null; then
            echo "✓ websocket-proxy is running successfully"
        else
            echo "✗ websocket-proxy failed to start. Check /tmp/websocket-proxy.log"
        fi
    else
        echo "⚠ Port 8766 is already in use, skipping websocket-proxy startup"
    fi
else
    echo "⚠ websocket-proxy not found, skipping startup"
fi

echo "========== Custom Startup Complete =========="

# Keep the script running (the parent vnc_startup.sh monitors process health)
sleep infinity
