#!/bin/bash
# nemo_archive_tools.sh - Archive packing/unpacking wrapper for Nemo

action="$1"
shift

case "$action" in
    extract)
        if [ $# -lt 1 ]; then exit 1; fi
        for file in "$@"; do
            dir_name="${file%.*}"
            # Remove secondary extensions like .tar
            dir_name="${dir_name%.tar}"
            
            mkdir -p "$dir_name"
            
            # Identify format and unpack
            case "$file" in
                *.tar.bz2|*.tbz2) tar -xvjf "$file" -C "$dir_name" ;;
                *.tar.gz|*.tgz)   tar -xvzf "$file" -C "$dir_name" ;;
                *.tar.xz|*.txz)   tar -xvf "$file" -C "$dir_name" ;;
                *.tar)            tar -xvf "$file" -C "$dir_name" ;;
                *.zip)            unzip "$file" -d "$dir_name" ;;
                *.7z)             7z x "$file" -o"$dir_name" ;;
                *.rar)            unrar x "$file" "$dir_name/" || 7z x "$file" -o"$dir_name" ;;
                *)                
                    rmdir "$dir_name"
                    zenity --error --title="Archive Error" --text="Unsupported archive format for: $(basename "$file")"
                    continue
                    ;;
            esac
        done
        notify-send -a "Archive Tools" "Extraction Complete" "Extracted $# archives."
        ;;
        
    create)
        if [ $# -lt 1 ]; then exit 1; fi
        # Choose format
        format=$(zenity --list --title="Create Archive" --column="Format" "zip" "tar.gz" "tar.xz" "7z")
        if [ -n "$format" ]; then
            # Choose destination archive filename
            default_name="archive.${format}"
            if [ $# -eq 1 ]; then
                default_name="$(basename "$1").${format}"
            fi
            
            archive_path=$(zenity --file-selection --save --confirm-overwrite --title="Save Archive As..." --filename="$default_name")
            if [ -n "$archive_path" ]; then
                # Ensure correct extension
                if [[ "$archive_path" != *."$format" ]]; then
                    archive_path="${archive_path}.${format}"
                fi
                
                case "$format" in
                    zip)
                        zip -r "$archive_path" "$@"
                        ;;
                    tar.gz)
                        tar -cvzf "$archive_path" "$@"
                        ;;
                    tar.xz)
                        tar -cvf "$archive_path" "$@"
                        ;;
                    7z)
                        7z a "$archive_path" "$@"
                        ;;
                esac
                notify-send -a "Archive Tools" "Archive Created" "Saved as $(basename "$archive_path")"
            fi
        fi
        ;;
        
    *)
        echo "Unknown action: $action"
        exit 1
        ;;
esac
