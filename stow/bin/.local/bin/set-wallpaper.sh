#!/usr/bin/env bash
# Script to set wallpaper in Sway and Thunar context menu
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export SWAYSOCK="${SWAYSOCK:-$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n 1)}"

IMAGE_PATH="${1:-}"

if [ -z "$IMAGE_PATH" ]; then
    notify-send "Wallpaper Error" "No image path provided." -i dialog-error
    exit 1
fi

if [ ! -f "$IMAGE_PATH" ]; then
    notify-send "Wallpaper Error" "File does not exist: $IMAGE_PATH" -i dialog-error
    exit 1
fi

# Update 02_appearance.conf directly with exact file path
APPEARANCE_CONF="/home/skc/.config/sway/config.d/02_appearance.conf"
sed -i "s|^output \* bg .*|output \* bg $IMAGE_PATH fill|" "$APPEARANCE_CONF"

# Update current_wallpaper link
ln -sf "$IMAGE_PATH" "/home/skc/.config/sway/current_wallpaper"

# Kill existing swaybg & set wallpaper via swaymsg + background swaybg
killall swaybg 2>/dev/null || true
swaybg -i "$IMAGE_PATH" -m fill >/dev/null 2>&1 &
swaymsg "output * bg $IMAGE_PATH fill" 2>/dev/null || true

notify-send "Wallpaper Updated" "Set wallpaper to $(basename "$IMAGE_PATH")" -i preferences-desktop-wallpaper
