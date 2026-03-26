#!/bin/bash
set -euo pipefail

USERNAME="john"
USER_HOME="/home/john"
INSTALL_DIR="$USER_HOME/.local/bin"

echo "Installing python MQTT library & wlr-randr..."
sudo apt update
sudo apt install -y python3-paho-mqtt wlr-randr

echo "Copying unblanker script..."
sudo -u "$USERNAME" mkdir -p "$INSTALL_DIR"
sudo cp unblanker.py "$INSTALL_DIR/unblanker.py"
sudo chmod +x "$INSTALL_DIR/unblanker.py"
sudo chown "$USERNAME:$USERNAME" "$INSTALL_DIR/unblanker.py"

echo "Creating systemd background service..."
cat <<EOF | sudo tee /etc/systemd/system/kiosk-unblanker.service >/dev/null
[Unit]
Description=MQTT Screen Unblanker for Kiosk
After=network-online.target kiosk.service
Wants=network-online.target

[Service]
User=${USERNAME}
Group=${USERNAME}
# These environments are required for wlr-randr to talk to labwc's compositor
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/bin/python3 -u ${INSTALL_DIR}/unblanker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling and starting the unblanker..."
sudo systemctl daemon-reload
sudo systemctl enable kiosk-unblanker.service
sudo systemctl restart kiosk-unblanker.service

echo "MQTT Unblanker installed and running in the background!"
