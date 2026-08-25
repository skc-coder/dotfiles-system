#!/bin/bash
# System-wide game blocker:
# 1. Permanently blocks Roblox / Sober / Vinegar / Grapejuice.
# 2. Limits Minecraft (Official, Prism, Lunar, MultiMC, etc.) to 1 hour (3600 seconds) daily.
# 3. Sends a notification 2 minutes before the limit is reached.

BLOCKED_PATTERN="roblox|sober|vinegar|grapejuice|discord|vesktop|webcord|armcord|com\.discordapp"
MINECRAFT_PATTERN="minecraft"
DAILY_LIMIT_SECONDS=0
WARN_BEFORE_SECONDS=0 # No warning needed for 0-hour limit

STATE_DIR="$HOME/.local/state/game-blocker"
mkdir -p "$STATE_DIR"

notify_user() {
    local title="$1"
    local msg="$2"
    local urgency="${3:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        # Try sending to current user session
        notify-send -u "$urgency" -a "Game Blocker" "$title" "$msg" 2>/dev/null || true
    fi
}

while true; do
    TODAY=$(date +%Y-%m-%d)
    USAGE_FILE="$STATE_DIR/mc_$TODAY.seconds"
    WARN_FILE="$STATE_DIR/mc_$TODAY.warned"

    if [ ! -f "$USAGE_FILE" ]; then
        echo "0" > "$USAGE_FILE"
    fi

    # 1. Immediately kill permanently blocked games & apps (Roblox / Sober / Discord)
    pkill -9 -f -i "$BLOCKED_PATTERN" 2>/dev/null
    pkill -9 -f "com.discordapp.Discord" 2>/dev/null
    pkill -9 -f "/app/discord/Discord" 2>/dev/null
    killall -9 Discord discord com.discordapp.Discord vesktop webcord armcord 2>/dev/null

    # Read current usage
    CURRENT_USAGE=$(cat "$USAGE_FILE" 2>/dev/null || echo 0)

    # 2. Check if Minecraft process is active
    MC_PIDS=$(pgrep -f -i "$MINECRAFT_PATTERN" 2>/dev/null)

    if [ -n "$MC_PIDS" ]; then
        if [ "$CURRENT_USAGE" -ge "$DAILY_LIMIT_SECONDS" ]; then
            # Limit reached! Kill immediately.
            pkill -9 -f -i "$MINECRAFT_PATTERN" 2>/dev/null
            notify_user "Minecraft Time Limit Reached" "Daily 1-hour limit reached. Minecraft closed for today!" "critical"
            sleep 0.5
            continue
        fi

        # Minecraft is running and under limit. Increment usage by 1 second.
        CURRENT_USAGE=$((CURRENT_USAGE + 1))
        echo "$CURRENT_USAGE" > "$USAGE_FILE"

        # 2-minute warning check (at 58 mins / 3480 seconds)
        if [ "$CURRENT_USAGE" -ge $((DAILY_LIMIT_SECONDS - WARN_BEFORE_SECONDS)) ] && [ ! -f "$WARN_FILE" ]; then
            touch "$WARN_FILE"
            notify_user "Minecraft Warning" "You have 2 minutes remaining of your 1-hour daily Minecraft limit!" "critical"
        fi

        sleep 0.5
    else
        # Fast 0.2s poll loop so blocked apps get instantly terminated on launch
        sleep 0.2
    fi
done

