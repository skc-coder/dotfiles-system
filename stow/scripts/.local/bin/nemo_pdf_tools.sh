#!/bin/bash
# nemo_pdf_tools.sh - PDF manipulation tool for Nemo file manager actions

action="$1"
shift

case "$action" in
    compress)
        # Check files
        if [ $# -lt 1 ]; then exit 1; fi
        for file in "$@"; do
            # Prompt user for quality using Zenity
            quality=$(zenity --list --title="PDF Compression Quality" \
                --column="Preset" --column="Description" \
                "screen" "Low resolution (72 dpi) - Screen viewing" \
                "ebook" "Medium resolution (150 dpi) - E-Books" \
                "printer" "High resolution (300 dpi) - Printing" \
                "prepress" "Maximum quality (300 dpi) - Prepress color" \
                --default-interactive)
            
            if [ -n "$quality" ]; then
                quality_preset=$(echo "$quality" | awk '{print $1}')
                out_file="${file%.pdf}_compressed.pdf"
                gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/"$quality_preset" \
                   -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$out_file" "$file"
                notify-send -a "PDF Tools" "PDF Compressed" "Saved as $(basename "$out_file")"
            fi
        done
        ;;
        
    split)
        if [ $# -lt 1 ]; then exit 1; fi
        for file in "$@"; do
            range=$(zenity --entry --title="PDF Split" --text="Enter page range to extract (e.g. 1-3, 5, 8-end):" --entry-text="1-end")
            if [ -n "$range" ]; then
                # Get total pages
                total_pages=$(pdfinfo "$file" | grep Pages: | awk '{print $2}')
                
                # Parse range (e.g. 1-3)
                if [[ "$range" == *-* ]]; then
                    first_page=$(echo "$range" | cut -d'-' -f1)
                    last_page=$(echo "$range" | cut -d'-' -f2)
                    if [ "$last_page" = "end" ]; then
                        last_page=$total_pages
                    fi
                else
                    first_page="$range"
                    last_page="$range"
                fi
                
                out_file="${file%.pdf}_pages_${first_page}_to_${last_page}.pdf"
                gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER \
                   -dFirstPage="$first_page" -dLastPage="$last_page" \
                   -sOutputFile="$out_file" "$file"
                notify-send -a "PDF Tools" "PDF Split Complete" "Extracted pages to $(basename "$out_file")"
            fi
        done
        ;;
        
    to_image)
        if [ $# -lt 1 ]; then exit 1; fi
        for file in "$@"; do
            format=$(zenity --list --title="Image Format" --column="Format" "png" "jpg" "webp")
            if [ -n "$format" ]; then
                prefix="${file%.pdf}_page"
                pdftoppm -"$format" -r 150 "$file" "$prefix"
                notify-send -a "PDF Tools" "PDF to Image Complete" "Pages extracted as $format"
            fi
        done
        ;;
        
    merge)
        # Requires at least two files selected
        if [ $# -lt 2 ]; then
            zenity --error --title="PDF Merge Error" --text="Please select 2 or more PDF files to merge."
            exit 1
        fi
        
        out_file=$(zenity --file-selection --save --confirm-overwrite --title="Save Merged PDF As..." --filename="merged.pdf")
        if [ -n "$out_file" ]; then
            # Ensure it ends with .pdf
            if [[ "$out_file" != *.pdf ]]; then
                out_file="${out_file}.pdf"
            fi
            pdfunite "$@" "$out_file"
            notify-send -a "PDF Tools" "PDF Merge Complete" "Saved merged PDF as $(basename "$out_file")"
        fi
        ;;
        
    *)
        echo "Unknown action: $action"
        exit 1
        ;;
esac
