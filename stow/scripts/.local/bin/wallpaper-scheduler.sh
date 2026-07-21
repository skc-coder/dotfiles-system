#!/usr/bin/env bash

WALLPAPERS_DIR="/home/skc/Pictures/wallpapers"
SWAY_LINK="/home/skc/.config/sway/current_wallpaper"

# Function to change to a random wallpaper
change_wallpaper() {
    if [ ! -d "$WALLPAPERS_DIR" ]; then
        return
    fi

    # Read files
    mapfile -t FILES < <(find "$WALLPAPERS_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \))
    
    if [ ${#FILES[@]} -eq 0 ]; then
        return
    fi

    # Get current wallpaper path (dereference symlink)
    CURRENT=""
    if [ -L "$SWAY_LINK" ]; then
        CURRENT=$(readlink -f "$SWAY_LINK")
    fi

    # Pick a random one that is not current (if more than 1 option is available)
    FILTERED=()
    for f in "${FILES[@]}"; do
        if [ "$f" != "$CURRENT" ]; then
            FILTERED+=("$f")
        fi
    done

    if [ ${#FILTERED[@]} -gt 0 ]; then
        SELECTED="${FILTERED[RANDOM % ${#FILTERED[@]}]}"
    else
        SELECTED="${FILES[RANDOM % ${#FILES[@]}]}"
    fi

    # Apply
    ln -sf "$SELECTED" "$SWAY_LINK"
    swaymsg "output * bg $SWAY_LINK fill"
}

# Run loop
while true; do
    sleep 1800
    change_wallpaper
done
