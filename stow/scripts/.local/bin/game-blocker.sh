#!/bin/bash
# System-wide lightweight background blocker for Minecraft and Roblox.
# Runs in a loop to instantly terminate any game processes.

while true; do
    # Terminate launchers and game binaries immediately
    pkill -9 -f -i "sklauncher"
    pkill -9 -f -i "minecraft"
    pkill -9 -f -i "roblox"
    pkill -9 -f -i "vinegar"
    pkill -9 -f -i "grapejuice"
    pkill -9 -f -i "sober"
    sleep 120
done
