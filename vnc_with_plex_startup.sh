#!/bin/bash
### Plex Discord Control - Additional Startup Script
### This runs AFTER the core vnc_startup.sh has started VNC and audio
### It only adds Plex-specific customizations

echo "=== Plex Discord Control Startup ==="

# Create Discord IPC socket directory for rich presence
mkdir -p /tmp/runtime-kasm-user/discord-ipc-0 2>/dev/null || true
chmod 755 /tmp/runtime-kasm-user/discord-ipc-0 2>/dev/null || true

# Set up DBus session address for Flatpak and desktop apps
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# Ensure XDG runtime directory exists
export XDG_RUNTIME_DIR="/tmp/runtime-kasm-user"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# --- START PIPEWIRE FOR AUDIO ---
echo "Starting PipeWire audio system..."

# Create PipeWire directories
export PIPEWIRE_RUNTIME_DIR="/tmp/runtime-kasm-user"
export PULSE_RUNTIME_PATH="/tmp/runtime-kasm-user/pulse"
export PULSE_SERVER="unix:${PULSE_RUNTIME_PATH}/native"

mkdir -p "$PULSE_RUNTIME_PATH" 2>/dev/null || true
mkdir -p /tmp/pipewire-0 2>/dev/null || true
chmod 755 /tmp/pipewire-0 2>/dev/null || true
chmod 755 "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 755 "$PULSE_RUNTIME_PATH" 2>/dev/null || true
chown -R 1000:0 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Kill any existing PipeWire processes
pkill -f pipewire 2>/dev/null || true
pkill -f wireplumber 2>/dev/null || true
sleep 1

# Clean up old sockets
rm -f /tmp/pipewire-0.lock /tmp/pipewire-0/lock "$PULSE_RUNTIME_PATH/native" 2>/dev/null || true

# Start PipeWire daemon
echo "Starting PipeWire daemon..."
PIPEWIRE_RUNTIME_DIR=/tmp/runtime-kasm-user pipewire > /tmp/pipewire.log 2>&1 &
sleep 2

# Start WirePlumber (session manager)
echo "Starting WirePlumber..."
PIPEWIRE_RUNTIME_DIR=/tmp/runtime-kasm-user wireplumber > /tmp/wireplumber.log 2>&1 &
sleep 2

# Start PipeWire-Pulse (PulseAudio compatibility layer)
echo "Starting PipeWire-Pulse..."
PIPEWIRE_RUNTIME_DIR=/tmp/runtime-kasm-user PULSE_RUNTIME_PATH=/tmp/runtime-kasm-user/pulse pipewire-pulse > /tmp/pipewire-pulse.log 2>&1 &
sleep 2

# Wait for PulseAudio socket
echo "Waiting for PulseAudio socket..."
MAX_RETRIES=15
RETRY=0
while [ ! -S "$PULSE_RUNTIME_PATH/native" ] && [ $RETRY -lt $MAX_RETRIES ]; do
    echo "Waiting for pulse socket... ($RETRY/$MAX_RETRIES)"
    sleep 1
    RETRY=$((RETRY + 1))
done

if [ -S "$PULSE_RUNTIME_PATH/native" ]; then
    echo "✓ PulseAudio socket ready at $PULSE_RUNTIME_PATH/native"
else
    echo "⚠ WARNING: PulseAudio socket not ready after ${MAX_RETRIES}s - audio may not work"
fi

# --- FIREFOX EXTENSION SETUP ---
echo "Installing Plex Discord Control Firefox Extension..."

FIREFOX_PROFILE="$HOME/.mozilla/firefox/kasm"
EXT_FOLDER="$FIREFOX_PROFILE/extensions/plex-discord-control@local"
EXT_XPI_PATH="/app/plex-firefox-ext/plex-discord-control@local.xpi"

if [ -f "$EXT_XPI_PATH" ]; then
    echo "Found Firefox extension XPI at: $EXT_XPI_PATH"

    # Create extension directory
    mkdir -p "$EXT_FOLDER"
    rm -rf "$EXT_FOLDER"/* 2>/dev/null || true

    # Unpack the .xpi file
    unzip -q "$EXT_XPI_PATH" -d "$EXT_FOLDER" 2>/dev/null || true

    if [ -f "$EXT_FOLDER/manifest.json" ]; then
        echo "✓ Firefox Extension unpacked: $EXT_FOLDER"

        # Create extensions.json
        EXT_JSON="$FIREFOX_PROFILE/extensions.json"
        cat > "$EXT_JSON" << EXTJSON
{
  "schemaVersion": 4,
  "addons": [
    {
      "id": "plex-discord-control@local",
      "version": "1.2.1",
      "location": "app-system",
      "path": "$EXT_FOLDER",
      "type": "extension",
      "enabled": true,
      "applicationVersion": "89.0",
      "platformVersion": "89.0"
    }
  ]
}
EXTJSON
        echo "✓ Firefox Extension registered"
    else
        echo "⚠ Warning: Failed to unpack extension"
    fi
else
    echo "⚠ Warning: Extension XPI not found at $EXT_XPI_PATH"
fi

# Configure Firefox for WebSocket connections
FIREFOX_USERJS="$FIREFOX_PROFILE/user.js"
mkdir -p "$FIREFOX_PROFILE"
cat > "$FIREFOX_USERJS" << 'USERJS'
// Allow connections without strict HTTPS requirements
user_pref("dom.security.https_only_mode", false);
user_pref("security.mixed_content.block_active_content", false);
user_pref("security.OCSP.enabled", 0);
user_pref("security.cert_pinning.enforcement_level", 0);
user_pref("security.fileuri.strict_origin_policy", false);
// PipeWire audio support
user_pref("media.cubeb.backend", "pipewire");
user_pref("media.cubeb.sandbox", false);
USERJS
echo "✓ Firefox configured for WebSocket and audio"

# Create Firefox profiles.ini
mkdir -p "$HOME/.mozilla/firefox"
cat > "$HOME/.mozilla/firefox/profiles.ini" << 'PROFILES'
[Profile0]
Name=kasm
IsRelative=1
Path=kasm
Default=1
PROFILES

# --- START CUSTOM STARTUP SCRIPTS ---
echo "Starting Plex Discord custom startup scripts..."

# Start Plex Discord server
if [ -x /dockerstartup/custom_startup-plex-discord.sh ]; then
    echo "Starting custom_startup-plex-discord.sh..."
    /dockerstartup/custom_startup-plex-discord.sh &
fi

# Start Discord custom startup (if exists)
if [ -x /dockerstartup/custom_startup.sh ]; then
    echo "Starting custom_startup.sh..."
    /dockerstartup/custom_startup.sh &
fi

echo "=== Plex Discord Control Startup Complete ==="

# Pass control to the next script in the ENTRYPOINT chain
exec "$@"
