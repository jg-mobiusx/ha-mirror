#!/usr/bin/env python3
import time
import json
import subprocess
import os
import paho.mqtt.client as mqtt

# Load Configuration
CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "unblanker.json")

try:
    with open(CONFIG_FILE, "r") as f:
        config = json.load(f)
except Exception as e:
    print(f"Error loading {CONFIG_FILE}: {e}")
    # Fallback to safe defaults
    config = {
        "mqtt_broker": "127.0.0.1",
        "mqtt_port": 1883,
        "mqtt_user": "",
        "mqtt_pass": "",
        "mqtt_topic": "frigate/events",
        "timeout_seconds": 1800,
        "trigger_labels": ["person"]
    }

MQTT_BROKER = config.get("mqtt_broker", "127.0.0.1")
MQTT_PORT = config.get("mqtt_port", 1883)
MQTT_USER = config.get("mqtt_user", "")
MQTT_PASS = config.get("mqtt_pass", "")
MQTT_TOPIC = config.get("mqtt_topic", "frigate/events")
TIMEOUT_SECONDS = config.get("timeout_seconds", 1800)
TRIGGER_LABELS = config.get("trigger_labels", ["person", "car"])

last_trigger_time = time.time()
screen_is_on = None

def get_active_outputs():
    """Retrieve a list of active display outputs from wlr-randr"""
    try:
        result = subprocess.run(["wlr-randr"], capture_output=True, text=True, check=True)
        outputs = []
        for line in result.stdout.splitlines():
            # wlr-randr prints the output name at the start of a line without indentation
            if line and not line[0].isspace():
                outputs.append(line.split()[0])
        return outputs if outputs else ["HDMI-A-1", "HDMI-A-2"]
    except Exception as e:
        print(f"Failed to query wlr-randr outputs: {e}")
        return ["HDMI-A-1", "HDMI-A-2"]

def set_screen_state(state):
    """Turns the active HDMI outputs ON or OFF using wlr-randr natively via labwc"""
    global screen_is_on
    
    # Do not force repeated commands if the screen is already in the requested state
    if screen_is_on == state:
        return
        
    cmd = "on" if state else "off"
    
    outputs = get_active_outputs()
    for output in outputs:
        subprocess.run(["wlr-randr", "--output", output, "--" + cmd], check=False)
    
    screen_is_on = state
    print(f"Screen physically commanded to {'ON' if state else 'OFF'} on {', '.join(outputs)}")

def on_connect(client, userdata, flags, rc):
    print(f"Connected to MQTT broker with result code {rc}")
    client.subscribe(MQTT_TOPIC)
    # Ensure screen is on when script boots
    set_screen_state(True)

def on_message(client, userdata, msg):
    global last_trigger_time
    try:
        payload = json.loads(msg.payload.decode())
        
        # We check if Frigate caught any of our configured trigger labels
        if payload.get("after", {}).get("label") in TRIGGER_LABELS:
            last_trigger_time = time.time()
            set_screen_state(True)
            
    except json.JSONDecodeError:
        pass

# Setup MQTT Client
client = mqtt.Client()
if MQTT_USER and MQTT_PASS:
    client.username_pw_set(MQTT_USER, MQTT_PASS)

client.on_connect = on_connect
client.on_message = on_message

print(f"Connecting to MQTT broker at {MQTT_BROKER}...")
try:
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
except Exception as e:
    print(f"Failed to connect: {e}")
    exit(1)

client.loop_start()

# Start the main timer loop
try:
    while True:
        time.sleep(5)
        
        # Turn off the screen if the timeout has passed since the last trigger
        if time.time() - last_trigger_time > TIMEOUT_SECONDS:
            set_screen_state(False)
            
except KeyboardInterrupt:
    print("Exiting...")
    set_screen_state(True)
    client.loop_stop()
