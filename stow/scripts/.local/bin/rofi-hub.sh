#!/usr/bin/env bash

# Rofi Hub Script Launcher

options="🧹 सिस्टम कैशे और डिस्क सफाई (Clean Disk)\n🛡️ वीपीएन चालू/बंद (Toggle VPN)\n🎧 ऑडियो आउटपुट (Audio Switcher)\n🌀 पंखा प्रोफ़ाइल (Fan Profile)\n📊 सिस्टम जानकारी (System Info)"

chosen=$(echo -e "$options" | rofi -dmenu -p "त्वरित हब (Quick Hub)" -i)

case "$chosen" in
    *"वीपीएन"*|*"VPN"*)
        ~/.local/bin/vpn-toggle.sh
        ;;
    *"ऑडियो"*|*"Audio"*)
        pavucontrol &
        ;;
    *"पंखा"*|*"Fan"*)
        /home/skc/dev/dotfiles/scripts/fan-toggle.sh
        ;;
    *"सफाई"*|*"Clean"*)
        kitty --title "सिस्टम सफाई" -e ~/.local/bin/system-clean
        ;;
    *"जानकारी"*|*"System Info"*)
        kitty -e htop &
        ;;
esac
