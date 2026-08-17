#!/usr/bin/env bash

# Rofi Power / Session Menu Script for Sway

options="⚡ Shutdown\n🔄 Reboot\n🌙 Suspend\n🔒 Lock\n🚪 Logout"

chosen=$(echo -e "$options" | rofi -dmenu -p "Power Menu" -i)

case "$chosen" in
    *"Lock"*)
        swaylock -f
        ;;
    *"Logout"*)
        swaymsg exit
        ;;
    *"Suspend"*)
        systemctl suspend
        ;;
    *"Reboot"*)
        systemctl reboot
        ;;
    *"Shutdown"*)
        systemctl poweroff
        ;;
esac
