#!/bin/bash
###
# Discord Rich Presence for Plex startup script
# This script initializes and starts the Discord Rich Presence service
###

set -e

echo "Discord Rich Presence for Plex - Startup Script"

# Config directory
DRPP_CONFIG_DIR="${HOME}/.config/discord-rich-presence-plex"
DRPP_CONFIG="${DRPP_CONFIG_DIR}/config.yaml"
DRPP_LOG="${DRPP_CONFIG_DIR}/drpp.log"

# Ensure config directory exists
mkdir -p "$DRPP_CONFIG_DIR"

# Check if config exists, if not create template
if [ ! -f "$DRPP_CONFIG" ]; then
    echo "Creating DRPP configuration template at $DRPP_CONFIG"
    cat > "$DRPP_CONFIG" << 'EOF'
# Discord Rich Presence for Plex Configuration
# For more information, visit: https://github.com/phin05/discord-rich-presence-plex

# Plex Server Configuration
plex:
  # Plex server URL (required)
  url: "http://plex:32400"

  # Plex API token (required)
  # Get this from: Settings > Account > Authorized devices and apps
  token: ""

# Discord Configuration
discord:
  # Discord client ID (required)
  # Create an app at: https://discord.com/developers/applications
  client_id: ""

  # Discord client secret (optional, for advanced features)
  client_secret: ""

# Application Settings
app:
  # Enable/disable rich presence
  enabled: true

  # Update interval in seconds (default: 15)
  update_interval: 15

  # Show album art in rich presence
  show_image: true

  # Hide private content in presence
  hide_private: false

  # Enable debug logging
  debug: false

# User Configuration
user:
  # Username to monitor (leave empty to monitor all users)
  username: ""

  # Only show presence when playing media
  only_when_playing: true

# Network Configuration
network:
  # Timeout for connections in seconds
  timeout: 10

  # Enable SSL verification
  verify_ssl: true

EOF
    echo "Template created. Please edit $DRPP_CONFIG with your Plex token and Discord credentials."
fi

# Function to check if config is properly filled
check_config() {
    if ! grep -q '^  token: "[^"]*[^"]"' "$DRPP_CONFIG" || grep -q 'token: ""' "$DRPP_CONFIG"; then
        echo "WARNING: Plex token not configured in $DRPP_CONFIG"
        return 1
    fi

    if ! grep -q 'client_id: "[^"]*[^"]"' "$DRPP_CONFIG" || grep -q 'client_id: ""' "$DRPP_CONFIG"; then
        echo "WARNING: Discord client ID not configured in $DRPP_CONFIG"
        return 1
    fi

    return 0
}

# Check configuration
if ! check_config; then
    echo "DRPP is not fully configured. Please update:"
    echo "  - Plex token: Get from Settings > Account > Authorized devices"
    echo "  - Discord client ID: Create app at https://discord.com/developers/applications"
    echo ""
    echo "Configuration file: $DRPP_CONFIG"
    exit 1
fi

# Set environment variables from config if they exist
if [ -f "${DRPP_CONFIG_DIR}/env" ]; then
    echo "Loading environment variables from ${DRPP_CONFIG_DIR}/env"
    source "${DRPP_CONFIG_DIR}/env"
fi

# Start DRPP service
echo "Starting Discord Rich Presence for Plex..."

# Run with logging
python3 /opt/discord-rich-presence-plex/main.py \
    2>&1 | tee -a "$DRPP_LOG"
