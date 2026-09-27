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
TITLE=$(echo "$FOCUSED_JSON" | jq -r '.title // .name // empty')
WINDOW_ROLE=$(echo "$FOCUSED_JSON" | jq -r '.window_properties.role // empty')
WINDOW_TYPE=$(echo "$FOCUSED_JSON" | jq -r '.window_properties.window_type // empty')

# Build precise criteria so we match the specific window TYPE/ROLE/TITLE, NOT the whole app
CRITERIA_PARTS=()
LABEL_PARTS=()

if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ]; then
    CRITERIA_PARTS+=("app_id=\"${APP_ID}\"")
    LABEL_PARTS+=("app_id: ${APP_ID}")
elif [ -n "$CLASS" ] && [ "$CLASS" != "null" ]; then
    CRITERIA_PARTS+=("class=\"${CLASS}\"")
    LABEL_PARTS+=("class: ${CLASS}")
fi

# Add specific window qualifiers if available (window_role, window_type, or exact title)
if [ -n "$WINDOW_ROLE" ] && [ "$WINDOW_ROLE" != "null" ]; then
    CRITERIA_PARTS+=("window_role=\"${WINDOW_ROLE}\"")
    LABEL_PARTS+=("role: ${WINDOW_ROLE}")
elif [ -n "$WINDOW_TYPE" ] && [ "$WINDOW_TYPE" != "null" ]; then
    CRITERIA_PARTS+=("window_type=\"${WINDOW_TYPE}\"")
    LABEL_PARTS+=("type: ${WINDOW_TYPE}")
elif [ -n "$TITLE" ] && [ "$TITLE" != "null" ]; then
    # Sanitize title for regex/string matching
    SAFE_TITLE=$(echo "$TITLE" | sed 's/"/\\"/g')
    CRITERIA_PARTS+=("title=\"${SAFE_TITLE}\"")
    LABEL_PARTS+=("title: ${TITLE:0:30}")
fi

if [ ${#CRITERIA_PARTS[@]} -eq 0 ]; then
    notify-send "Sway Floating Manager" "Could not determine window criteria!" -u warning 2>/dev/null || true
    exit 1
fi

# Join criteria array into Sway syntax: [app_id="foo" title="bar"]
IFS=" "
CRITERIA="[${CRITERIA_PARTS[*]}]"
LABEL="${LABEL_PARTS[*]}"

# Escape brackets for exact regex pattern matching in sed/grep
ESCAPED_CRITERIA=$(echo "$CRITERIA" | sed 's/\[/\\[/g; s/\]/\\]/g; s/"/\\"/g')

# If rule exists in config file, remove it (Toggle OFF persistence)
if grep -F "$CRITERIA" "$CONFIG_FILE" >/dev/null 2>&1; then
    sed -i "|\Q${CRITERIA}\E|d" "$CONFIG_FILE" 2>/dev/null || sed -i "/for_window ${ESCAPED_CRITERIA}/d" "$CONFIG_FILE"
    swaymsg "floating disable" >/dev/null 2>&1 || true
    swaymsg reload >/dev/null 2>&1 || true
    notify-send "Sway Floating Manager" "❌ Removed persistent floating for:\n${LABEL}\nWindow will now launch TILED." -i window-pop-out 2>/dev/null || true
else
    # Rule doesn't exist: add it (Toggle ON persistence)
    RULE_LINE="for_window ${CRITERIA} floating enable, move position center"
    echo "$RULE_LINE" >> "$CONFIG_FILE"
    swaymsg "floating enable" >/dev/null 2>&1 || true
    swaymsg reload >/dev/null 2>&1 || true
    notify-send "Sway Floating Manager" "📌 Saved persistent floating for:\n${LABEL}\nOnly this window type will launch FLOATING." -i window-new 2>/dev/null || true
fi
