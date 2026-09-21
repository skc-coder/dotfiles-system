#!/usr/bin/env bash

# Rofi Calculator & Web Launcher

INPUT=$(rofi -dmenu -p "Run / Calc / Web:" -i)

[ -z "$INPUT" ] && exit 0

# Check if input is math expression
if [[ "$INPUT" =~ ^[0-9+/*%^\(\)\.\ -]+$ ]] && [[ "$INPUT" =~ [0-9] ]]; then
    RESULT=$(python3 -c "print($INPUT)" 2>/dev/null)
    if [ -n "$RESULT" ]; then
        echo -n "$RESULT" | wl-copy
        notify-send "Calculator" "$INPUT = $RESULT (Copied to clipboard!)" -i dialog-information
        exit 0
    fi
fi

# Check if input is a URL or search query
if [[ "$INPUT" =~ ^https?:// ]] || [[ "$INPUT" =~ \.[a-z]{2,4}$ ]]; then
    brave-browser "$INPUT" &
else
    # Default web search
    encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(' '.join(sys.argv[1:])))" "$INPUT")
    brave-browser "https://www.google.com/search?q=$encoded" &
fi
