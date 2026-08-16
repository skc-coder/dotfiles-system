#!/usr/bin/env bash

# Toggle scratchpad terminal script
if swaymsg -t get_tree | grep -q '"app_id": "scratchpad_term"'; then
    swaymsg '[app_id="scratchpad_term"] scratchpad show'
else
    kitty --app-id scratchpad_term &
    sleep 0.2
    swaymsg '[app_id="scratchpad_term"] move scratchpad'
    swaymsg '[app_id="scratchpad_term"] scratchpad show'
fi
