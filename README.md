# ha-mirror

## What is this?
**ha-mirror** is a custom script suite that turns a Raspberry Pi into a high-performance, appliance-style "smart mirror" or wall-mounted kiosk specifically designed to display a Home Assistant dashboard. It runs cleanly in the background without a bulky desktop environment, saving system resources and maximizing stability.

## Why do I need it?
Running a web browser 24/7 on a Raspberry Pi can be sluggish, resource-heavy, and prone to breaking. Standard setups often boot into a full Linux desktop environment, which wastes memory. `ha-mirror` solves this by:
1. **Skipping the desktop entirely**: It boots directly into a barebones display manager (`labwc` on modern Wayland) and immediately launches your Home Assistant dashboard in hardware-accelerated, full-screen mode.
2. **Smart Power Management**: Instead of keeping the display glowing 24/7, the included `unblanker` script seamlessly integrates with your MQTT broker. When a smart sensor or security camera (like Frigate) detects a person, `ha-mirror` instantly wakes up the monitor. After a period of inactivity, it turns the screen completely off to save power and prevent burn-in.
3. **Built-in Camera Streaming Support**: It integrates a native, low-latency setup (`go2rtc`) designed precisely for viewing live security cameras without stuttering.

## How does it work?
These scripts automate the tedious Linux configuration needed to get all these pieces securely talking to each other. 
- You run **`build-kiosk-v2.sh`** to download packages, create the background `systemd` services, and point the kiosk directly to your Home Assistant URL.
- You run **`install-unblanker.sh`** to deploy the `unblanker.py` script. This becomes a background service that silently listens to your MQTT network and translates Home Assistant occupancy events into physical monitor commands (`wlr-randr`) to wake or sleep the screen.

---

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