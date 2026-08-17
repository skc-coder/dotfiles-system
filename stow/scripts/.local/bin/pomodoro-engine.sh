#!/usr/bin/env bash
# ==============================================================================
# Hardcore Pomodoro Work/Rest Engine with Sway DND Integration
# Commands: start | stop | status | toggle
# State file stored in /tmp/pomodoro_state
# ==============================================================================

STATE_FILE="/tmp/pomodoro_state"
WORK_MINS=25
REST_MINS=5

get_time() { date +%s; }

play_sound() {
    local freq=$1
    if command -v pw-cat &>/dev/null; then
        # Generate quick sine wave audio alert via pw-cat / paplay or system bell
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || printf "\a"
    else
        printf "\a"
    fi
}

enable_dnd() {
    if command -v makoctl &>/dev/null; then
        makoctl mode -a do-not-disturb 2>/dev/null || true
    fi
}

disable_dnd() {
    if command -v makoctl &>/dev/null; then
        makoctl mode -r do-not-disturb 2>/dev/null || true
    fi
}

cmd_start() {
    local now
    now=$(get_time)
    local end_time=$((now + WORK_MINS * 60))
    echo "WORK:$end_time" > "$STATE_FILE"
    enable_dnd
    notify-send -a "Pomodoro Engine" -i appointment-new "Focus Session Started 🎯" "${WORK_MINS}m deep work timer running. Notifications muted."
    play_sound 440
}

cmd_stop() {
    rm -f "$STATE_FILE"
    disable_dnd
    notify-send -a "Pomodoro Engine" -i process-stop "Pomodoro Reset 🛑" "Timer stopped. Notifications unmuted."
}

cmd_toggle() {
    if [[ -f "$STATE_FILE" ]]; then
        cmd_stop
    else
        cmd_start
    fi
}

cmd_status() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"text": "🍅 Off", "class": "idle", "tooltip": "Click to start 25m Focus Session"}'
        exit 0
    fi

    local state_data
    state_data=$(cat "$STATE_FILE")
    local mode="${state_data%%:*}"
    local target_time="${state_data##*:}"
    local now
    now=$(get_time)
    local diff=$((target_time - now))

    if [[ $diff -le 0 ]]; then
        if [[ "$mode" == "WORK" ]]; then
            # Work finished -> Start Rest
            local new_end=$((now + REST_MINS * 60))
            echo "REST:$new_end" > "$STATE_FILE"
            disable_dnd
            play_sound 880
            notify-send -a "Pomodoro Engine" -i dialog-information "Work Session Done! 🎉" "Take a ${REST_MINS} minute rest break."
            echo "{\"text\": \"☕ Rest ${REST_MINS}:00\", \"class\": \"break\", \"tooltip\": \"Rest break running\"}"
        else
            # Rest finished -> Reset to idle
            rm -f "$STATE_FILE"
            play_sound 440
            notify-send -a "Pomodoro Engine" -i dialog-information "Rest Finished! 💪" "Ready for the next focus sprint."
            echo '{"text": "🍅 Ready", "class": "idle", "tooltip": "Click to start focus session"}'
        fi
        exit 0
    fi

    local mins=$((diff / 60))
    local secs=$((diff % 60))
    local formatted
    formatted=$(printf "%02d:%02d" "$mins" "$secs")

    if [[ "$mode" == "WORK" ]]; then
        echo "{\"text\": \"🎯 ${formatted}\", \"class\": \"work\", \"tooltip\": \"Focus Mode Active (${WORK_MINS}m)\"}"
    else
        echo "{\"text\": \"☕ ${formatted}\", \"class\": \"break\", \"tooltip\": \"Rest Break Active (${REST_MINS}m)\"}"
    fi
}

case "${1:-status}" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    toggle) cmd_toggle ;;
    status) cmd_status ;;
    *) echo "Usage: $0 {start|stop|toggle|status}" ;;
esac
