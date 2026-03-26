#!/bin/bash
set -euo pipefail

# Load central config
source "$(dirname "$0")/config.sh"

USER_ID="1000"

echo "Updating system..."
sudo apt update
sudo apt full-upgrade -y

echo "Installing native Wayland kiosk packages..."
sudo apt install -y --no-install-recommends \
  labwc \
  seatd \
  chromium-browser \
  wayland-protocols \
  wget \
  curl \
  tar \
  rpicam-apps

echo "Installing go2rtc..."
GO2RTC_VERSION="1.9.8"
sudo wget -q -O /usr/local/bin/go2rtc "https://github.com/AlexxIT/go2rtc/releases/download/v${GO2RTC_VERSION}/go2rtc_linux_arm64"
sudo chmod +x /usr/local/bin/go2rtc

echo "Creating user scripts & configs..."
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.config/labwc"
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.config/go2rtc"

# 1. Labwc Autostart
cat <<EOF | sudo -u "$USERNAME" tee "$USER_HOME/.config/labwc/autostart" >/dev/null
# Launch Chromium natively on Wayland
exec /usr/bin/chromium-browser \\
  --enable-features=UseOzonePlatform \\
  --ozone-platform=wayland \\
  --kiosk \\
  --noerrdialogs \\
  --disable-infobars \\
  --no-first-run \\
  --disable-session-crashed-bubble \\
  --enable-hardware-overlays \\
  --enable-gpu-rasterization \\
  --enable-zero-copy \\
  \${HA_URL}
EOF

# 2. go2rtc config
cat <<EOF | sudo -u "$USERNAME" tee "$USER_HOME/.config/go2rtc/go2rtc.yaml" >/dev/null
streams:
  picam:
    - exec:rpicam-vid -t 0 --inline --listen --port 8554
    
api:
  listen: ":1984"
EOF

echo "Creating systemd services..."

# Provide user permissions to DRM hardware and inputs
sudo usermod -aG video,render,input ${USERNAME}

# Kiosk Service (Labwc natively controlling the screen hardware)
cat <<EOF | sudo tee /etc/systemd/system/kiosk.service >/dev/null
[Unit]
Description=Labwc Wayland Kiosk
After=systemd-user-sessions.service network-online.target seatd.service
Wants=network-online.target seatd.service

[Service]
User=${USERNAME}
Group=${USERNAME}
PAMName=login
TTYPath=/dev/tty1
Environment=XDG_RUNTIME_DIR=/run/user/${USER_ID}
Environment=HOME=${USER_HOME}
Environment=WLR_LIBINPUT_NO_DEVICES=1
WorkingDirectory=${USER_HOME}
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/usr/bin/labwc
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# go2rtc Service
cat <<EOF | sudo tee /etc/systemd/system/go2rtc.service >/dev/null
[Unit]
Description=go2rtc Streaming Server
After=network-online.target
Wants=network-online.target

[Service]
User=${USERNAME}
Group=${USERNAME}
Environment=HOME=${USER_HOME}
WorkingDirectory=${USER_HOME}
ExecStart=/usr/local/bin/go2rtc -config ${USER_HOME}/.config/go2rtc/go2rtc.yaml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "Disabling conflicting TTY1 logins..."
sudo systemctl mask getty@tty1.service

echo "Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable seatd.service
sudo systemctl start seatd.service
sudo systemctl enable kiosk.service
sudo systemctl enable go2rtc.service

echo "Build complete. Reboot when ready."
