#!/usr/bin/env python3
import time
import json
import subprocess
import paho.mqtt.client as mqtt

# Configuration
MQTT_BROKER = "172.16.44.11"  # Your HA/Frigate IP
MQTT_PORT = 1883
MQTT_USER = ""                # Fill in if your broker requires auth
MQTT_PASS = ""                # Fill in if your broker requires auth
MQTT_TOPIC = "frigate/events"

TIMEOUT_SECONDS = 30 * 60     # 30 minutes

last_person_time = time.time()
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
    global last_person_time
    try:
        payload = json.loads(msg.payload.decode())
        
        # We only care about Frigate catching a 'person'
        if payload.get("after", {}).get("label") == "person":
            last_person_time = time.time()
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
        
        # If 30 minutes have passed since the last person ping, turn it off
        if time.time() - last_person_time > TIMEOUT_SECONDS:
            set_screen_state(False)
            
except KeyboardInterrupt:
    print("Exiting...")
    set_screen_state(True)
    client.loop_stop()
