#!/bin/bash
# Take a screenshot of a selected region, perform OCR using tesseract, and copy to clipboard.

temp_img=$(mktemp /tmp/ocr_XXXXXX.png)
temp_txt=$(mktemp /tmp/ocr_XXXXXX)

# Capture region using grim and slurp
if ! grim -g "$(slurp)" "$temp_img"; then
    notify-send -a "Sentry OCR" "OCR Cancelled" "No screenshot was captured."
    rm -f "$temp_img" "$temp_txt"
    exit 0
fi

if [ -f "$temp_img" ]; then
    # Run Tesseract OCR (outputs to temp_txt.txt)
    if tesseract "$temp_img" "$temp_txt" -l eng 2>/dev/null; then
        # Copy to Wayland clipboard using wl-copy
        if [ -f "${temp_txt}.txt" ]; then
            cleaned_text=$(cat "${temp_txt}.txt" | sed '/^[[:space:]]*$/d') # remove empty lines
            if [ -n "$cleaned_text" ]; then
                echo "$cleaned_text" | wl-copy
                notify-send -a "Sentry OCR" "OCR Complete" "Text successfully copied to clipboard."
            else
                notify-send -a "Sentry OCR" "OCR Failed" "No text could be extracted from image."
            fi
            rm -f "${temp_txt}.txt"
        fi
    else
        notify-send -a "Sentry OCR" "OCR Failed" "Tesseract OCR execution failed."
    fi
    rm -f "$temp_img"
fi
rm -f "$temp_txt"
