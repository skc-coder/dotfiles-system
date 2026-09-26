#!/usr/bin/env bash
# Script to set wallpaper in Sway and persist selection
set -euo pipefail

IMAGE_PATH="${1:-}"

if [ -z "$IMAGE_PATH" ]; then
    echo "Usage: set-wallpaper.sh <path-to-image>"
    exit 1
fi

if [ ! -f "$IMAGE_PATH" ]; then
    notify-send "Wallpaper Error" "File does not exist: $IMAGE_PATH" -i dialog-error
    exit 1
fi

SWAY_LINK="/home/skc/.config/sway/current_wallpaper"

# Create symlink for persistence across restarts
ln -sf "$IMAGE_PATH" "$SWAY_LINK"

# Stop background wallpaper scheduler if running to prevent overriding
pkill -f wallpaper-scheduler.sh 2>/dev/null || true

# Apply wallpaper dynamically via swaymsg
if swaymsg "output * bg $IMAGE_PATH fill"; then
    notify-send "Wallpaper Updated" "Set wallpaper to $(basename "$IMAGE_PATH")" -i preferences-desktop-wallpaper
else
    notify-send "Wallpaper Error" "Failed to update wallpaper via swaymsg." -i dialog-error
fi
