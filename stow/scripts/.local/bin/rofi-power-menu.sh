#!/usr/bin/env bash

# Rofi Power / Session Menu Script for Sway

options="⚡ बंद करें (Shutdown)\n🔄 पुनरारंभ करें (Reboot)\n🌙 स्लीप (Suspend)\n🔒 स्क्रीन लॉक (Lock)\n🚪 लॉग आउट (Logout)"

chosen=$(echo -e "$options" | rofi -dmenu -p "पावर मेनू (Power Menu)" -i)

case "$chosen" in
    *"लॉक"*|*"Lock"*)
        swaylock -f
        ;;
    *"लॉग आउट"*|*"Logout"*)
        swaymsg exit
        ;;
    *"स्लीप"*|*"Suspend"*)
        systemctl suspend
        ;;
    *"पुनरारंभ"*|*"Reboot"*)
        systemctl reboot
        ;;
    *"बंद"*|*"Shutdown"*)
        systemctl poweroff
        ;;
esac
