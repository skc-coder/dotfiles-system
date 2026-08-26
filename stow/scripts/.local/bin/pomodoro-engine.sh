#!/usr/bin/env bash
# ==============================================================================
# Complete Standard Multi-Session Pomodoro Engine for Waybar
# - 4 Work Sessions (25 min each)
# - Short Breaks (5 min each) after Sessions 1, 2, 3
# - Long Break (30 min) after Session 4
# - Uses Universfield Attention Chime on state transitions & starts work automatically
# State file format: MODE:END_TIME:CYCLE (e.g. WORK:1787654321:1)
# ==============================================================================

STATE_FILE="/tmp/pomodoro_state"
WORK_MINS=25
SHORT_BREAK_MINS=5
LONG_BREAK_MINS=30

TICK_MP3="/home/skc/.local/share/pomodoro-timer.mp3"
CHIME_MP3="/home/skc/.local/share/universfield-chime.mp3"
PID_FILE="/tmp/pomodoro_audio.pid"

get_time() { date +%s; }

play_chime() {
    if [[ -f "$CHIME_MP3" ]]; then
        (pw-play "$CHIME_MP3" 2>/dev/null || paplay "$CHIME_MP3" 2>/dev/null || mpv --no-video "$CHIME_MP3" 2>/dev/null) &
    fi
}

play_audio() {
    stop_audio
    if [[ -f "$TICK_MP3" ]]; then
        if command -v mpv &>/dev/null; then
            mpv --no-video --loop=no "$TICK_MP3" &>/dev/null &
            echo $! > "$PID_FILE"
        elif command -v ffplay &>/dev/null; then
            ffplay -nodisp -autoexit "$TICK_MP3" &>/dev/null &
            echo $! > "$PID_FILE"
        elif command -v pw-play &>/dev/null; then
            pw-play "$TICK_MP3" &>/dev/null &
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

update_waybar() {
    pkill -RTMIN+9 waybar 2>/dev/null || true
}

start_work_session() {
    local cycle=${1:-1}
    local now
    now=$(get_time)
    local end_time=$((now + WORK_MINS * 60))
    echo "WORK:$end_time:$cycle" > "$STATE_FILE"
    update_waybar
    play_chime
    play_audio
    notify-send -a "Pomodoro Engine" -i appointment-new "Focus Session ${cycle}/4 Started 🎯" "Focus for ${WORK_MINS} minutes."
}

start_break_session() {
    local cycle=$1
    local now
    now=$(get_time)
    stop_audio
    play_chime

    if [[ $cycle -ge 4 ]]; then
        # Long Break 30 mins after session 4
        local end_time=$((now + LONG_BREAK_MINS * 60))
        echo "LONG_BREAK:$end_time:$cycle" > "$STATE_FILE"
        update_waybar
        notify-send -a "Pomodoro Engine" -i dialog-information "Session 4 Complete! 🎉" "Enjoy a 30-minute Long Break."
    else
        # Short Break 5 mins after sessions 1, 2, 3
        local end_time=$((now + SHORT_BREAK_MINS * 60))
        echo "SHORT_BREAK:$end_time:$cycle" > "$STATE_FILE"
        update_waybar
        notify-send -a "Pomodoro Engine" -i dialog-information "Session ${cycle}/4 Finished! ☕" "Take a ${SHORT_BREAK_MINS}-minute break."
    fi
}

cmd_start() {
    start_work_session 1
}

cmd_stop() {
    rm -f "$STATE_FILE"
    stop_audio
    update_waybar
    notify-send -a "Pomodoro Engine" -i process-stop "Pomodoro Stopped 🛑" "Timer & audio reset."
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
        echo '{"text": "🍅 Off", "class": "idle", "tooltip": "Click to start Standard 4-Session Pomodoro Cycle"}'
        exit 0
    fi

    local state_data
    state_data=$(cat "$STATE_FILE")
    
    IFS=':' read -r mode target_time cycle <<< "$state_data"
    cycle=${cycle:-1}

    local now
    now=$(get_time)
    local diff=$((target_time - now))

    if [[ $diff -le 0 ]]; then
        if [[ "$mode" == "WORK" ]]; then
            # Work finished -> auto start break
            start_break_session "$cycle"
        elif [[ "$mode" == "SHORT_BREAK" ]]; then
            # Short Break finished -> auto start next work session
            local next_cycle=$((cycle + 1))
            start_work_session "$next_cycle"
        elif [[ "$mode" == "LONG_BREAK" ]]; then
            # Long break finished -> cycle complete, reset
            rm -f "$STATE_FILE"
            stop_audio
            play_chime
            notify-send -a "Pomodoro Engine" -i trophy "Full Pomodoro Cycle Completed! 🏆" "Great job! Click to start a new cycle."
            echo '{"text": "🏆 Done", "class": "idle", "tooltip": "Cycle Complete! Click to start new session"}'
            exit 0
        fi
        state_data=$(cat "$STATE_FILE" 2>/dev/null)
        IFS=':' read -r mode target_time cycle <<< "$state_data"
        diff=$((target_time - now))
    fi

    local mins=$((diff / 60))
    local secs=$((diff % 60))
    local formatted
    formatted=$(printf "%02d:%02d" "$mins" "$secs")

    if [[ "$mode" == "WORK" ]]; then
        echo "{\"text\": \"🎯 [${cycle}/4] ${formatted}\", \"class\": \"work\", \"tooltip\": \"Session ${cycle} of 4 (${WORK_MINS}m)\"}"
    elif [[ "$mode" == "SHORT_BREAK" ]]; then
        echo "{\"text\": \"☕ [Rest ${cycle}] ${formatted}\", \"class\": \"break\", \"tooltip\": \"Short Break after Session ${cycle} (${SHORT_BREAK_MINS}m)\"}"
    elif [[ "$mode" == "LONG_BREAK" ]]; then
        echo "{\"text\": \"🌴 [Long Rest] ${formatted}\", \"class\": \"break\", \"tooltip\": \"Long Break after Cycle (${LONG_BREAK_MINS}m)\"}"
    fi
}

case "${1:-status}" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    toggle) cmd_toggle ;;
    status) cmd_status ;;
    *) echo "Usage: $0 {start|stop|toggle|status}" ;;
esac
