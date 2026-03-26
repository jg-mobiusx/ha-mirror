#!/bin/bash
set -euo pipefail

# Load central config
source "$(dirname "$0")/config.sh"

USER_ID="1000"

echo "Updating system..."
sudo apt update
sudo apt full-upgrade -y

echo "Installing kiosk packages..."
sudo apt install -y --no-install-recommends \
  xserver-xorg \
  x11-xserver-utils \
  xinit \
  openbox \
  chromium-browser \
  unclutter \
  dbus-x11

echo "Creating user scripts..."
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.local/bin"
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.config/openbox"

cat <<EOF | sudo -u "$USERNAME" tee "$USER_HOME/.local/bin/start-kiosk.sh" >/dev/null
#!/bin/bash
set -e

export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export DISPLAY=:0

xset s off
xset -dpms
xset s noblank

unclutter -idle 0.5 -root &

sleep 2

exec /usr/bin/chromium \\
  --kiosk \\
  --noerrdialogs \\
  --disable-infobars \\
  --no-first-run \\
  --disable-session-crashed-bubble \\
  --media-router=0 \\
  --enable-gpu-rasterization \\
  \${HA_URL}
EOF

sudo chmod +x "$USER_HOME/.local/bin/start-kiosk.sh"
sudo chown "$USERNAME:$USERNAME" "$USER_HOME/.local/bin/start-kiosk.sh"

cat <<'EOF' | sudo -u "$USERNAME" tee "$USER_HOME/.config/openbox/autostart" >/dev/null
~/.local/bin/start-kiosk.sh &
EOF

echo "Creating kiosk systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/kiosk.service >/dev/null
[Unit]
Description=Chromium Kiosk
After=systemd-user-sessions.service network-online.target
Wants=network-online.target

[Service]
User=${USERNAME}
Group=${USERNAME}
PAMName=login
TTYPath=/dev/tty1
Environment=XDG_RUNTIME_DIR=/run/user/${USER_ID}
Environment=HOME=${USER_HOME}
Environment=DISPLAY=:0
WorkingDirectory=${USER_HOME}
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/usr/bin/startx /usr/bin/openbox-session -- :0 vt1 -keeptty -nocursor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Configuring tty1 autologin..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USERNAME} --noclear %I \$TERM
EOF

echo "Enabling kiosk service..."
sudo systemctl daemon-reload
sudo systemctl enable kiosk.service

echo "Build complete. Reboot when ready."
