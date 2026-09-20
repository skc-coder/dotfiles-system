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
        
    to_pdf)
        if [ $# -lt 1 ]; then exit 1; fi
        out_file=$(zenity --file-selection --save --confirm-overwrite --title="Save PDF As..." --filename="images_combined.pdf")
        if [ -n "$out_file" ]; then
            if [[ "$out_file" != *.pdf ]]; then
                out_file="${out_file}.pdf"
            fi
            python3 -c "
import sys, re
from PIL import Image

image_paths = sys.argv[2:]
def natural_sort_key(path):
    import os
    basename = os.path.basename(path)
    return [int(text) if text.isdigit() else text.lower() for text in re.split(r'(\d+)', basename)]

image_paths.sort(key=natural_sort_key)
if image_paths:
    img_list = []
    first_img = None
    for p in image_paths:
        try:
            img = Image.open(p).convert('RGB')
            if first_img is None:
                first_img = img
            else:
                img_list.append(img)
        except Exception as e:
            print(f'Error opening {p}: {e}')
    if first_img:
        first_img.save(sys.argv[1], save_all=True, append_images=img_list)
" "$out_file" "$@"
            notify-send -a "Image Tools" "Image to PDF Complete" "Saved PDF as $(basename "$out_file")"
        fi
        ;;

    to_pdf)
        if [ $# -lt 1 ]; then exit 1; fi
        out_file=$(zenity --file-selection --save --confirm-overwrite --title="Save PDF As..." --filename="images_combined.pdf")
        if [ -n "$out_file" ]; then
            if [[ "$out_file" != *.pdf ]]; then
                out_file="${out_file}.pdf"
            fi
            python3 -c "
import sys, re
from PIL import Image

image_paths = sys.argv[2:]
def natural_sort_key(path):
    import os
    basename = os.path.basename(path)
    return [int(text) if text.isdigit() else text.lower() for text in re.split(r'(\d+)', basename)]

image_paths.sort(key=natural_sort_key)
if image_paths:
    img_list = []
    first_img = None
    for p in image_paths:
        try:
            img = Image.open(p).convert('RGB')
            if first_img is None:
                first_img = img
            else:
                img_list.append(img)
        except Exception as e:
            print(f'Error opening {p}: {e}')
    if first_img:
        first_img.save(sys.argv[1], save_all=True, append_images=img_list)
" "$out_file" "$@"
            notify-send -a "Image Tools" "Image to PDF Complete" "Saved PDF as $(basename "$out_file")"
        fi
        ;;

    *)
        echo "Unknown action: $action"
        exit 1
        ;;
esac
