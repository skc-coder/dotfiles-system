#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CONFIG_FILE="$HOME/.config/sway/config"

# Get focused node details from swaymsg
FOCUSED_JSON=$(swaymsg -t get_tree | jq '.. | select(.focused? == true)')

if [ -z "$FOCUSED_JSON" ] || [ "$FOCUSED_JSON" = "null" ]; then
    notify-send "Sway Floating Manager" "No focused window detected!" -u critical 2>/dev/null || true
    exit 1
fi

APP_ID=$(echo "$FOCUSED_JSON" | jq -r '.app_id // empty')
CLASS=$(echo "$FOCUSED_JSON" | jq -r '.window_properties.class // empty')
IS_FLOATING=$(echo "$FOCUSED_JSON" | jq -r '.floating // "none"')

CRITERIA=""
LABEL=""

if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ]; then
    CRITERIA="[app_id=\"${APP_ID}\"]"
    LABEL="app_id: ${APP_ID}"
elif [ -n "$CLASS" ] && [ "$CLASS" != "null" ]; then
    CRITERIA="[class=\"${CLASS}\"]"
    LABEL="class: ${CLASS}"
else
    notify-send "Sway Floating Manager" "Could not determine app_id or window class!" -u warning 2>/dev/null || true
    exit 1
fi

# Escape brackets for exact regex pattern matching in sed/grep
ESCAPED_CRITERIA=$(echo "$CRITERIA" | sed 's/\[/\\[/g; s/\]/\\]/g')

# If rule exists in config file, remove it (Toggle OFF persistence)
if grep -E "for_window +${ESCAPED_CRITERIA} +floating enable" "$CONFIG_FILE" >/dev/null 2>&1; then
    sed -i "/for_window +${ESCAPED_CRITERIA} +floating enable/d" "$CONFIG_FILE"
    swaymsg "floating disable" >/dev/null 2>&1 || true
    swaymsg reload >/dev/null 2>&1 || true
    notify-send "Sway Floating Manager" "❌ Removed persistent floating for ${LABEL}\nApp will now launch TILED." -i window-pop-out 2>/dev/null || true
else
    # Rule doesn't exist: add it (Toggle ON persistence)
    RULE_LINE="for_window ${CRITERIA} floating enable, move position center"
    echo "$RULE_LINE" >> "$CONFIG_FILE"
    swaymsg "floating enable" >/dev/null 2>&1 || true
    swaymsg reload >/dev/null 2>&1 || true
    notify-send "Sway Floating Manager" "📌 Saved persistent floating for ${LABEL}\nApp will always launch FLOATING." -i window-new 2>/dev/null || true
fi
