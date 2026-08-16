#!/usr/bin/env bash

# Rofi Emoji & Symbol Picker

emojis="😀 Grinning Face\n😂 Tears of Joy\n🔥 Fire\n✨ Sparkles\n🚀 Rocket\n💡 Idea / Bulb\n🎉 Party\n👍 Thumbs Up\n❤️ Red Heart\n💻 Laptop / Code\n🌐 Globe / Web\n💬 Speech Bubble\n🎧 Headphones\n📁 Folder\n⚙️ Settings\n⚠️ Warning\n🔒 Lock\n🔑 Key\n⚡ Lightning / Power"

chosen=$(echo -e "$emojis" | rofi -dmenu -p "Emoji Picker" -i)

if [ -n "$chosen" ]; then
    symbol=$(echo "$chosen" | awk '{print $1}')
    echo -n "$symbol" | wl-copy
    notify-send "Emoji Picker" "Copied $symbol to clipboard!" -i dialog-information
fi
