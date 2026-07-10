#!/bin/bash
# nemo_image_tools.sh - Image manipulation actions for Nemo

action="$1"
shift

case "$action" in
    convert)
        if [ $# -lt 1 ]; then exit 1; fi
        format=$(zenity --list --title="Convert Image" --column="Format" "png" "jpg" "webp")
        if [ -n "$format" ]; then
            for file in "$@"; do
                # Determine new filename
                new_file="${file%.*}.${format}"
                convert "$file" "$new_file"
            done
            notify-send -a "Image Tools" "Conversion Complete" "Converted $# images to $format"
        fi
        ;;
        
    resize)
        if [ $# -lt 1 ]; then exit 1; fi
        size=$(zenity --entry --title="Resize Image" --text="Enter target width or percentage (e.g. 1920, 800, 50%):" --entry-text="50%")
        if [ -n "$size" ]; then
            # Check if percentage
            if [[ "$size" == *% ]]; then
                resize_arg="$size"
            else
                resize_arg="${size}x"
            fi
            
            for file in "$@"; do
                ext="${file##*.}"
                base="${file%.*}"
                new_file="${base}_resized.${ext}"
                convert "$file" -resize "$resize_arg" "$new_file"
            done
            notify-send -a "Image Tools" "Resizing Complete" "Resized $# images to $size"
        fi
        ;;
        
    compress)
        if [ $# -lt 1 ]; then exit 1; fi
        quality=$(zenity --scale --title="Image Compression" --text="Select compression quality (10-100):" --min-value=10 --max-value=100 --value=80)
        if [ -n "$quality" ]; then
            for file in "$@"; do
                ext="${file##*.}"
                base="${file%.*}"
                new_file="${base}_compressed.${ext}"
                convert "$file" -quality "$quality" "$new_file"
            done
            notify-send -a "Image Tools" "Compression Complete" "Compressed $# images with quality $quality%"
        fi
        ;;
        
    *)
        echo "Unknown action: $action"
        exit 1
        ;;
esac
