#!/bin/bash
# System-wide lightweight background blocker for Roblox.
# Runs in a loop to instantly terminate any game processes.

while true; do
    # Terminate launchers and game binaries immediately using a single regex pattern
    pkill -9 -f -i "roblox|vinegar|grapejuice|sober"
    sleep 3
done
