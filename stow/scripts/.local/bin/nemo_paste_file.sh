#!/bin/bash
# nemo_paste_file.sh - Paste clipboard text into a new file with auto-detected extension.

dir_path="$1"
if [ -z "$dir_path" ] || [ ! -d "$dir_path" ]; then
    dir_path=$(pwd)
fi

# Get clipboard content using wl-paste (Wayland)
clip_content=$(wl-paste 2>/dev/null)
if [ -z "$clip_content" ]; then
    zenity --error --title="Paste Error" --text="Clipboard is empty or does not contain text."
    exit 1
fi

# Heuristic extension detection
ext="txt"
if [[ "$clip_content" =~ ^#\  || "$clip_content" == *"**"* || "$clip_content" == *"\`\`\`"* ]]; then
    ext="md"
elif [[ "$clip_content" == *"import "* || "$clip_content" == *"def "* || "$clip_content" == *"print("* ]] && [[ "$clip_content" != *"#include"* ]]; then
    ext="py"
elif [[ "$clip_content" == *"#include"* || "$clip_content" == *"int main("* || "$clip_content" == *"std::"* ]]; then
    if [[ "$clip_content" == *"std::"* || "$clip_content" == *"using namespace"* || "$clip_content" == *"iostream"* ]]; then
        ext="cpp"
    else
        ext="c"
    fi
fi

# Ask user for filename using Zenity
filename=$(zenity --entry --title="Create File from Clipboard" --text="Enter filename:" --entry-text="pasted_file.${ext}")

if [ -n "$filename" ]; then
    target_path="${dir_path}/${filename}"
    echo "$clip_content" > "$target_path"
    notify-send -a "Paste Tool" "File Created" "Saved as $filename"
fi
