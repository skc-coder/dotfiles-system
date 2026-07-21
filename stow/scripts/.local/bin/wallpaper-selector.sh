#!/usr/bin/env bash

export XDG_SESSION_TYPE=wayland

WALLPAPERS_DIR="/home/skc/Pictures/wallpapers"
SWAY_LINK="/home/skc/.config/sway/current_wallpaper"

# 1. Check if wallpapers directory exists and has files
if [ ! -d "$WALLPAPERS_DIR" ]; then
    notify-send "Wallpaper Selector" "Wallpapers directory not found." -i dialog-error
    exit 1
fi

# 2. Get list of files
mapfile -t FILES < <(find "$WALLPAPERS_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | sort)

if [ ${#FILES[@]} -eq 0 ]; then
    notify-send "Wallpaper Selector" "No wallpapers found in $WALLPAPERS_DIR" -i dialog-error
    exit 1
fi

# 3. Create Rofi menu options
MENU_OPTIONS=""
for file in "${FILES[@]}"; do
    filename=$(basename "$file")
    if [ -z "$MENU_OPTIONS" ]; then
        MENU_OPTIONS="$filename"
    else
        MENU_OPTIONS="${MENU_OPTIONS}\n${filename}"
    fi
done

# 4. Display Rofi Menu
CHOICE=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -display-backend wl -p "Select Wallpaper:")

# Exit safely if the user hits Escape or clicks away
if [ -z "$CHOICE" ]; then
    exit 0
fi

# Clean choice string
CHOICE=$(echo "$CHOICE" | tr -d '\r')

# 5. Apply the selected wallpaper
SELECTED_PATH="${WALLPAPERS_DIR}/${CHOICE}"

if [ -f "$SELECTED_PATH" ]; then
    ln -sf "$SELECTED_PATH" "$SWAY_LINK"
    swaymsg "output * bg $SWAY_LINK fill"
    notify-send "Wallpaper Selector" "Wallpaper changed to $CHOICE" -i preferences-desktop-wallpaper
else
    notify-send "Wallpaper Selector" "Error: Wallpaper file not found." -i dialog-error
fi
