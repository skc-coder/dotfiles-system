#!/usr/bin/env bash
# ==============================================================================
# Hardcore Pomodoro Work/Rest Engine with Sway DND Integration
# Commands: start | stop | status | toggle
# State file stored in /tmp/pomodoro_state
# ==============================================================================

STATE_FILE="/tmp/pomodoro_state"
WORK_MINS=25
REST_MINS=5

MP3_FILE="/home/skc/.local/share/pomodoro-timer.mp3"
PID_FILE="/tmp/pomodoro_audio.pid"

get_time() { date +%s; }

play_audio() {
    stop_audio
    if [[ -f "$MP3_FILE" ]]; then
        if command -v mpv &>/dev/null; then
            mpv --no-video --loop=no "$MP3_FILE" &>/dev/null &
            echo $! > "$PID_FILE"
        elif command -v ffplay &>/dev/null; then
            ffplay -nodisp -autoexit "$MP3_FILE" &>/dev/null &
            echo $! > "$PID_FILE"
        elif command -v pw-play &>/dev/null; then
            pw-play "$MP3_FILE" &>/dev/null &
            echo $! > "$PID_FILE"
        elif command -v paplay &>/dev/null; then
            paplay "$MP3_FILE" &>/dev/null &
            echo $! > "$PID_FILE"
        fi
    fi
}

stop_audio() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        pkill -P "$pid" 2>/dev/null || true
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    pkill -f "pomodoro-timer.mp3" 2>/dev/null || true
}

enable_dnd() {
    :
}

disable_dnd() {
    :
}

update_waybar() {
    pkill -RTMIN+9 waybar 2>/dev/null || true
}

cmd_start() {
    local now
    now=$(get_time)
    local end_time=$((now + WORK_MINS * 60))
    echo "WORK:$end_time" > "$STATE_FILE"
    update_waybar
    play_audio
    notify-send -a "Pomodoro Engine" -i appointment-new "Focus Session Started 🎯" "${WORK_MINS}m ticking pomodoro audio started."
}

cmd_stop() {
    rm -f "$STATE_FILE"
    stop_audio
    update_waybar
    notify-send -a "Pomodoro Engine" -i process-stop "Pomodoro Reset 🛑" "Timer & sound stopped."
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
            notify-send -a "Pomodoro Engine" -i dialog-information "Work Session Done! 🎉" "Take a ${REST_MINS} minute rest break."
            echo "{\"text\": \"☕ Rest ${REST_MINS}:00\", \"class\": \"break\", \"tooltip\": \"Rest break running\"}"
        else
            # Rest finished -> Reset to idle
            rm -f "$STATE_FILE"
            stop_audio
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
