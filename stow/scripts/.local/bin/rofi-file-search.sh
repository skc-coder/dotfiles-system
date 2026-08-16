#!/usr/bin/env bash

# Rofi Smart Smart File Search with Frequency/Recency Tracker

CACHE_DIR="$HOME/.cache/rofi-file-search"
FREQ_FILE="$CACHE_DIR/file_freq.txt"
mkdir -p "$CACHE_DIR"
touch "$FREQ_FILE"

# Exclude useless heavy directories (.git, node_modules, cache, system dirs, tmp, venv, target)
SEARCH_DIRS=("$HOME/dev" "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Desktop" "$HOME/.config")

# Find index of files
mapfile -t FILES < <(find "${SEARCH_DIRS[@]}" \
    \( -path "*/.git*" -o -path "*/node_modules*" -o -path "*/.cache*" -o -path "*/venv*" -o -path "*/target*" -o -path "*/.gemini*" \) -prune \
    -o -type f -print 2>/dev/null)

# Prioritize frequently used files
MENU=""
if [ -s "$FREQ_FILE" ]; then
    # Sort files by frequency count descending
    FREQ_SORTED=$(sort -nr -k2 "$FREQ_FILE" | awk '{print $1}')
    for f in $FREQ_SORTED; do
        if [ -f "$f" ]; then
            filename=$(basename "$f")
            MENU="${MENU}[FREQ] $filename → $f\n"
        fi
    done
fi

for f in "${FILES[@]}"; do
    filename=$(basename "$f")
    if ! grep -q "$f" <<< "$MENU"; then
        MENU="${MENU}$filename → $f\n"
    fi
done

SELECTION=$(echo -e "$MENU" | rofi -dmenu -p "Search Files:" -i)

if [ -n "$SELECTION" ]; then
    FILE_PATH=$(echo "$SELECTION" | awk -F ' → ' '{print $2}')
    if [ -f "$FILE_PATH" ]; then
        # Increment frequency count in tracker
        if grep -q "^$FILE_PATH " "$FREQ_FILE"; then
            count=$(grep "^$FILE_PATH " "$FREQ_FILE" | awk '{print $2}')
            new_count=$((count + 1))
            sed -i "s|^$FILE_PATH $count|$FILE_PATH $new_count|" "$FREQ_FILE"
        else
            echo "$FILE_PATH 1" >> "$FREQ_FILE"
        fi

        # Open file with default application or editor
        xdg-open "$FILE_PATH" 2>/dev/null || xdg-open "$FILE_PATH" &
        notify-send "File Search" "Opened: $(basename "$FILE_PATH")" -i dialog-information
    fi
fi
