# ha-mirror

A suite of scripts to build a high-performance, appliance-style Raspberry Pi kiosk for displaying Home Assistant dashboards. Features include native Wayland compositing (via `labwc`), low-latency camera streaming (`go2rtc`), and automated screen unblanking based on MQTT events (e.g., Frigate person detection).

## Scripts Overview

* **`build-kiosk-v2.sh`**: The recommended installation script. It builds a native Wayland kiosk using `labwc` and hardware-accelerated Chromium, along with `go2rtc` for streaming.
* **`build-kiosk.sh`**: The older X11/Openbox based setup script. Its usage is deprecated in favor of `v2` for better performance.
* **`install-unblanker.sh`**: Sets up `unblanker.py` and registers it as a background systemd service.
* **`unblanker.py`**: An MQTT client that listens to Frigate events and automatically unblanks the connected HDMI display(s) via `wlr-randr` when a person is detected. It automatically discovers active monitors via labwc.

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone git@github.com:jg-mobiusx/ha-mirror.git
   cd ha-mirror
   ```

2. **Configure your settings:**
   Edit the scripts prior to execution to insert your specific deployment parameters:
   * In `build-kiosk-v2.sh` (or `build-kiosk.sh`): Update `USERNAME`, `USER_HOME`, and `HA_URL`.
   * In `install-unblanker.sh`: Update `USERNAME` and `USER_HOME`.
   * In `unblanker.py`: Update `MQTT_BROKER`, and optionally `MQTT_USER` / `MQTT_PASS`.

3. **Deploy:**
   Make the script executable and run it:
   ```bash
   chmod +x build-kiosk-v2.sh
   ./build-kiosk-v2.sh
   ```

*(Note: Commit your changes locally, but please verify you are not committing any personal IP addresses, URLs, usernames, passwords, or other credentials to public version control!)*
