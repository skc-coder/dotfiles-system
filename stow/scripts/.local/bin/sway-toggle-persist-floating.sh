#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/sway/config"

# Get focused node details from swaymsg
FOCUSED_JSON=$(swaymsg -t get_tree | jq '.. | select(.focused? == true)')

if [ -z "$FOCUSED_JSON" ] || [ "$FOCUSED_JSON" = "null" ]; then
    notify-send "Sway Floating Manager" "No focused window detected!" -u critical
    exit 1
fi

APP_ID=$(echo "$FOCUSED_JSON" | jq -r '.app_id // empty')
CLASS=$(echo "$FOCUSED_JSON" | jq -r '.window_properties.class // empty')
IS_FLOATING=$(echo "$FOCUSED_JSON" | jq -r '.floating // "none"')

# Determine window criteria (prefer app_id for Wayland native, class for XWayland)
CRITERIA=""
LABEL=""

if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ]; then
    CRITERIA="[app_id=\"$APP_ID\"]"
    LABEL="app_id: $APP_ID"
elif [ -n "$CLASS" ] && [ "$CLASS" != "null" ]; then
    CRITERIA="[class=\"$CLASS\"]"
    LABEL="class: $CLASS"
else
    notify-send "Sway Floating Manager" "Could not determine app_id or window class!" -u warning
    exit 1
fi

RULE_PATTERN="for_window ${CRITERIA} floating enable"
RULE_LINE="for_window ${CRITERIA} floating enable, move position center"

# Check if a rule for this app/class already exists in Sway config
if grep -Fq "for_window ${CRITERIA}" "$CONFIG_FILE"; then
    # Remove existing persistent rule (Toggle OFF persistent floating)
    sed -i "/for_window ${CRITERIA}/d" "$CONFIG_FILE"
    swaymsg "floating disable"
    swaymsg reload
    notify-send "Sway Persistent Floating" "Removed floating persistence for $LABEL\nWindow will now launch tiled." -i window-pop-out
else
    # Add persistent rule (Toggle ON persistent floating)
    echo "$RULE_LINE" >> "$CONFIG_FILE"
    swaymsg "floating enable"
    swaymsg reload
    notify-send "Sway Persistent Floating" "Saved $LABEL to ALWAYS launch floating!\nRule added to dotfiles." -i window-new
fi
