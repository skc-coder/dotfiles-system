#!/usr/bin/env bash

# Rofi Audio Output Switcher

SINKS=$(wpctl status | grep -A 10 "Sinks:" | grep -E "^\s*│\s*(\*|\s)*[0-9]+" | sed 's/[│*]//g' | sed 's/^[ \t]*//')

if [ -z "$SINKS" ]; then
    notify-send "Audio Switcher" "No audio output devices found." -i dialog-error
    exit 1
fi

SELECTION=$(echo -e "$SINKS" | rofi -dmenu -p "Select Audio Output:" -i)

if [ -n "$SELECTION" ]; then
    SINK_ID=$(echo "$SELECTION" | awk '{print $1}' | tr -d '.')
    if [ -n "$SINK_ID" ]; then
        wpctl set-default "$SINK_ID"
        DEVICE_NAME=$(echo "$SELECTION" | cut -d'.' -f2- | sed 's/^[ \t]*//')
        notify-send "Audio Switcher" "Switched default audio to: $DEVICE_NAME" -i audio-speakers
    fi
fi
