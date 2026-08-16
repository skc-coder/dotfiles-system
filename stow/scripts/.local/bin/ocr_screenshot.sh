#!/usr/bin/env bash
# ==============================================================================
# Wayland Smart Screen Snipper & Scanner
# Captures region via grim+slurp, auto-detects QR/Barcodes OR runs OCR,
# copies result to clipboard, and offers instant action (e.g. open URL).
# ==============================================================================

set -euo pipefail

TEMP_IMG=$(mktemp /tmp/snipper_XXXXXX.png)
TEMP_TXT=$(mktemp /tmp/snipper_XXXXXX)

cleanup() {
    rm -f "$TEMP_IMG" "$TEMP_TXT" "${TEMP_TXT}.txt"
}
trap cleanup EXIT

# 1. Capture selection
if ! grim -g "$(slurp)" "$TEMP_IMG" 2>/dev/null; then
    notify-send -a "Screen Snipper" -i edit-cut "Snipper Cancelled" "Selection was aborted."
    exit 0
fi

# 2. Try QR / Barcode detection first via zbarimg if installed
QR_RESULT=""
if command -v zbarimg &>/dev/null; then
    QR_RESULT=$(zbarimg --raw -q "$TEMP_IMG" 2>/dev/null || true)
fi

if [[ -n "$QR_RESULT" ]]; then
    echo -n "$QR_RESULT" | wl-copy
    notify-send -a "Screen Snipper" -i QR-code "QR / Code Scanned!" "Copied to clipboard:\n$QR_RESULT"
    
    # If it's a URL, prompt to open in browser
    if [[ "$QR_RESULT" =~ ^https?:// ]]; then
        if command -v xdg-open &>/dev/null; then
            xdg-open "$QR_RESULT" &
        fi
    fi
    exit 0
fi

# 3. Fallback to Tesseract OCR
if command -v tesseract &>/dev/null; then
    if tesseract "$TEMP_IMG" "$TEMP_TXT" -l eng 2>/dev/null; then
        if [[ -f "${TEMP_TXT}.txt" ]]; then
            RAW_TEXT=$(cat "${TEMP_TXT}.txt")
            CLEAN_TEXT=$(echo "$RAW_TEXT" | sed '/^[[:space:]]*$/d')
            
            if [[ -n "$CLEAN_TEXT" ]]; then
                echo -n "$CLEAN_TEXT" | wl-copy
                
                # Truncate preview for notification
                PREVIEW="${CLEAN_TEXT:0:120}"
                [[ ${#CLEAN_TEXT} -gt 120 ]] && PREVIEW="${PREVIEW}..."
                
                notify-send -a "Screen Snipper" -i edit-paste "OCR Extracted!" "Copied to clipboard:\n$PREVIEW"
                exit 0
            fi
        fi
    fi
fi

notify-send -a "Screen Snipper" -i dialog-warning "Extraction Failed" "No QR code, barcode, or readable text found."
