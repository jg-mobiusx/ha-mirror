#!/bin/bash
# config.sh - Central deployment configuration for ha-mirror scripts

# Auto-detect the primary non-root user (works confidently even when script is run with sudo)
USERNAME="${SUDO_USER:-$USER}"

if [ "$USERNAME" = "root" ]; then
    echo "Error: Please run this script with sudo as a normal user, not as the root user directly."
    exit 1
fi

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

# For the Kiosk scripts
HA_URL="http://YOUR_HA_IP:8123/dashboard-drive/0"
