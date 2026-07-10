#!/usr/bin/env bash

FAN_PATH="/sys/devices/platform/asus-nb-wmi/fan_boost_mode"
STATE_FILE="/tmp/fan_mode_state"

# Read last mode (default to 0 if not set)
current=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

# Cycle: 0 (normal) -> 1 (performance) -> 2 (silent) -> back to 0
case "$current" in
    0) next=1; label="Performance" ; icon="🚀" ;;
    1) next=2; label="Silent"      ; icon="🤫" ;;
    2) next=0; label="Normal"      ; icon="🌀" ;;
    *) next=0; label="Normal"      ; icon="🌀" ;;
esac

echo "$next" | sudo tee "$FAN_PATH" > /dev/null

if [ $? -eq 0 ]; then
    echo "$next" > "$STATE_FILE"
    notify-send -u normal "Fan Mode: $label $icon" "fan_boost_mode set to $next"
else
    notify-send -u critical "Fan Mode Toggle Failed" "Could not write to $FAN_PATH"
fi
