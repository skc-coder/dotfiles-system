#!/usr/bin/env bash

# Sway Keybinding Manager & Editor (Rofi + Zenity GUI)
SWAY_CONFIG="$HOME/.config/sway/config"

# 1. Action Selection
action=$(echo -e "➕ Add New Keybinding\n✏️ Edit / Change Existing Keybinding\n❌ Remove Keybinding\n🔄 Reload Sway Config" | rofi -dmenu -p "Sway Shortcut Manager" -i)

if [ -z "$action" ]; then
    exit 0
fi

case "$action" in
    *"Add"*)
        keycombo=$(zenity --entry --title="Add Keybinding" --text="Enter Key Combination (e.g., \$mod+Shift+x or Mod4+x):")
        [ -z "$keycombo" ] && exit 0
        
        command=$(zenity --entry --title="Add Keybinding" --text="Enter Command to Execute (e.g., brave-browser or ~/.local/bin/my-script.sh):")
        [ -z "$command" ] && exit 0
        
        # Append to Sway config
        echo -e "\nbindsym $keycombo exec $command" >> "$SWAY_CONFIG"
        swaymsg reload
        notify-send "Sway Shortcut Manager" "Added: bindsym $keycombo exec $command" -i dialog-information
        ;;
        
    *"Edit"*)
        # Parse existing bindsym lines
        bindsyms=$(grep -n "^bindsym" "$SWAY_CONFIG")
        chosen=$(echo -e "$bindsyms" | rofi -dmenu -p "Select Shortcut to Change" -i)
        [ -z "$chosen" ] && exit 0
        
        line_num=$(echo "$chosen" | cut -d':' -f1)
        old_line=$(echo "$chosen" | cut -d':' -f2-)
        
        new_line=$(zenity --entry --title="Edit Keybinding" --text="Edit full bindsym line:" --entry-text="$old_line")
        [ -z "$new_line" ] && exit 0
        
        # Replace line in config
        sed -i "${line_num}c\\${new_line}" "$SWAY_CONFIG"
        swaymsg reload
        notify-send "Sway Shortcut Manager" "Updated line $line_num to:\n$new_line" -i dialog-information
        ;;
        
    *"Remove"*)
        bindsyms=$(grep -n "^bindsym" "$SWAY_CONFIG")
        chosen=$(echo -e "$bindsyms" | rofi -dmenu -p "Select Shortcut to Delete" -i)
        [ -z "$chosen" ] && exit 0
        
        line_num=$(echo "$chosen" | cut -d':' -f1)
        sed -i "${line_num}d" "$SWAY_CONFIG"
        swaymsg reload
        notify-send "Sway Shortcut Manager" "Removed shortcut at line $line_num" -i dialog-warning
        ;;

    *"Reload"*)
        swaymsg reload
        notify-send "Sway Shortcut Manager" "Sway configuration reloaded successfully!" -i dialog-information
        ;;
esac
