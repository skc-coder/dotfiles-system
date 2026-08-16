#!/usr/bin/env bash

WALLPAPERS_DIR="/home/skc/Pictures/wallpapers"

if [ ! -d "$WALLPAPERS_DIR" ]; then
    exit 1
fi

change_wallpaper() {
    mapfile -t FILES < <(find "$WALLPAPERS_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \))
    if [ ${#FILES[@]} -eq 0 ]; then
        return
    fi

    SELECTED="${FILES[RANDOM % ${#FILES[@]}]}"

    # Kill existing swaybg processes so swaybg reloads the image instantly without caching issues
    pkill swaybg 2>/dev/null || true
    swaybg -o '*' -i "$SELECTED" -m fill &
}

while true; do
    change_wallpaper
    sleep 10
done
