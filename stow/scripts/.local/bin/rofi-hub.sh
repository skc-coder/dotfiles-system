#!/usr/bin/env bash

# Rofi Hub Script Launcher

options="🌐 Switch Default Browser\n🧹 Clear System Caches & Clean Disk\n🛡️ Toggle VPN\n🎧 Audio Output Switcher\n🌀 Toggle Fan Profile\n📊 System Info"

chosen=$(echo -e "$options" | rofi -dmenu -p "Quick Hub" -i)

case "$chosen" in
    *"Browser"*)
        ~/.local/bin/browser-selector
        ;;
    *"VPN"*)
        ~/.local/bin/vpn-toggle.sh
        ;;
    *"Audio"*)
        pavucontrol &
        ;;
    *"Fan"*)
        /home/skc/dev/dotfiles/scripts/fan-toggle.sh
        ;;
    *"Clear"*|*"Clean"*)
        kitty --title "System Clean" -e ~/.local/bin/system-clean
        ;;
    *"System Info"*)
        kitty -e htop &
        ;;
esac
