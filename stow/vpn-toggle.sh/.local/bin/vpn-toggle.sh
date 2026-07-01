#!/usr/bin/env bash

export XDG_SESSION_TYPE=wayland

# 1. Force kill ALL active connections using a wildcard system scan
teardown_all_vpns() {
    # Scan system network directories directly for any interfaces starting with "vpn-" or "proton"
    # This acts as your requested wildcard check and works without 'wg show' blocks
    local active_interfaces
    active_interfaces=$(find /sys/class/net/ -name "vpn-*" -o -name "proton" 2>/dev/null | awk -F'/' '{print $NF}')
    
    if [ ! -z "$active_interfaces" ]; then
        while read -r vpn; do
            if [ ! -z "$vpn" ]; then
                sudo /usr/bin/wg-quick down "$vpn"
            fi
        done <<< "$active_interfaces"
    fi
}

# 2. Build and launch the Rofi Menu
MENU_OPTIONS="⚡ [Auto Select Best Server]\n❌ [Disconnect VPN]"
LOCAL_CONFIGS=$(sudo /usr/bin/find /etc/wireguard/ -name "*.conf" -exec basename {} .conf \;)

if [ ! -z "$LOCAL_CONFIGS" ]; then
    MENU_OPTIONS="${MENU_OPTIONS}\n${LOCAL_CONFIGS}"
fi

CHOICE=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -display-backend wl -p "VPN Control:")

# Exit safely if the user hits Escape or clicks away
if [ -z "$CHOICE" ]; then
    exit 0
fi

# 3. Handle Disconnect Choice
if [ "$CHOICE" = "❌ [Disconnect VPN]" ]; then
    teardown_all_vpns
    pkill -RTMIN+4 waybar 2>/dev/null || true
    notify-send "Proton VPN" "All connections dropped." -i network-vpn
    exit 0
fi

# 4. Handle Auto Select Choice
if [ "$CHOICE" = "⚡ [Auto Select Best Server]" ]; then
    LIVE_LOADS=$(curl -s "https://protonvpn.ch" | jq -r '.Logicals[] | select(.Tier==0) | "\(.ExitCountry) \(.Load)"' 2>/dev/null)
    LOCAL_FILES=$(sudo /usr/bin/ls /etc/wireguard/ | grep "\.conf$" | sed 's/\.conf//g')

    BEST_CONFIG=""
    BEST_LOAD=101

    while read -r config; do
        if [[ "$config" =~ vpn-([a-zA-Z]{2})[0-9]* ]]; then
            country_code="${BASH_REMATCH,,}"
            country_load=$(echo "$LIVE_LOADS" | awk -v cc="${country_code^^}" '$1 == cc {print $2; exit}')
            
            if [ ! -z "$country_load" ] && [ "$country_load" -lt "$BEST_LOAD" ]; then
                BEST_LOAD=$country_load
                BEST_CONFIG=$config
            fi
        fi
    done <<< "$LOCAL_FILES"

    if [ ! -z "$BEST_CONFIG" ]; then
        CHOICE=$BEST_CONFIG
    else
        CHOICE=$(echo "$LOCAL_FILES" | head -n 1)
    fi
fi

# 5. Why some selections failed: Strip any accidental carriage returns (\r) from Rofi choice string
CHOICE=$(echo "$CHOICE" | tr -d '\r')

# 6. Execute Action: Clear old tunnels via system wildcard, then fire up the new one
teardown_all_vpns
notify-send "Proton VPN" "Connecting to $CHOICE..." -i network-vpn
sudo /usr/bin/wg-quick up "$CHOICE"
pkill -RTMIN+4 waybar 2>/dev/null || true

