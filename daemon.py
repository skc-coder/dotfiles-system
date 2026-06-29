import os
import sys
import time
import json
import threading
import subprocess
from datetime import datetime
from inotify_simple import INotify, flags

# Include dotfiles imports
from dotfiles import (
    load_config, load_pending, save_pending, is_ignored,
    DOTFILES_DIR, PENDING_FILE, CONFIG, find_stow_package
)

DEBOUNCE_TIME = float(os.environ.get("DOTFILES_DEBOUNCE", 600.0))  # default 10 minutes (600s)

def run_notification():
    try:
        # Dismiss any previous dotfiles notifications
        subprocess.run(["makoctl", "dismiss", "-a"], capture_output=True)
    except Exception:
        pass

    try:
        # Send Wayland-native notification with action using mako/notify-send
        cmd = [
            "notify-send",
            "-a", "dotfiles",
            "--action=open=Open TUI",
            "Dotfiles / Sentry",
            "New configurations detected. Click to review."
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        # notify-send prints the clicked action (e.g. "open")
        output = proc.stdout.strip()
        if output == "open":
            # Launch TUI reviewer in Kitty terminal
            # Use the virtual environment's dotfiles binary
            venv_bin = os.path.join(DOTFILES_DIR, ".venv", "bin", "dotfiles")
            if not os.path.exists(venv_bin):
                venv_bin = "dotfiles"  # fallback to path
            subprocess.Popen(["kitty", "--class", "dotfiles-tui", "-e", venv_bin, "review"])
    except Exception as e:
        print(f"Notification error: {e}", file=sys.stderr)

def watch_system():
    inotify = INotify()
    wd_to_path = {}

    watch_flags = (
        flags.CREATE | flags.MODIFY | flags.MOVED_TO | flags.DELETE | flags.MOVED_FROM
    )

    def add_watches_recursive(path):
        abs_path = os.path.abspath(os.path.expanduser(path))
        if not os.path.exists(abs_path):
            return
            
        if os.path.isdir(abs_path):
            if is_ignored(abs_path):
                return
            try:
                wd = inotify.add_watch(abs_path, watch_flags)
                wd_to_path[wd] = abs_path
            except Exception:
                pass
                
            for root, dirs, files in os.walk(abs_path):
                dirs[:] = [d for d in dirs if not is_ignored(os.path.join(root, d))]
                for d in dirs:
                    dir_path = os.path.join(root, d)
                    try:
                        wd = inotify.add_watch(dir_path, watch_flags)
                        wd_to_path[wd] = dir_path
                    except Exception:
                        pass
        else:
            # Single file
            parent = os.path.dirname(abs_path)
            try:
                wd = inotify.add_watch(parent, watch_flags)
                wd_to_path[wd] = parent
            except Exception:
                pass

    # Initial registration of watched paths from config
    watch_paths = CONFIG.get("watch", {}).get("paths", [])
    print(f"Registering watch paths: {watch_paths}")
    for p in watch_paths:
        add_watches_recursive(p)

    last_change_time = None
    has_unnotified_changes = False

    print("Sentry Daemon started. Watching files...")

    while True:
        try:
            # Read events with 1-second timeout to allow debounce checks
            events = inotify.read(timeout=1000)
            
            for event in events:
                path_dir = wd_to_path.get(event.wd)
                if not path_dir:
                    continue
                    
                full_path = os.path.join(path_dir, event.name)
                
                # Filter out ignored patterns
                if is_ignored(full_path):
                    continue

                # Determine type
                ftype = "config"
                if "local/bin" in full_path:
                    ftype = "script"
                elif "Applications" in full_path or full_path.endswith(".AppImage"):
                    ftype = "appimage"
                elif "fonts" in full_path:
                    ftype = "font"
                elif full_path.startswith("/etc") or full_path == "/etc/hosts":
                    ftype = "system"

                # Update pending.json immediately to prevent losing state
                pending = load_pending()
                
                # Check if already present in files list
                exists = any(f["path"] == full_path for f in pending["files"])
                if not exists:
                    pending["files"].append({
                        "path": full_path,
                        "type": ftype,
                        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M")
                    })
                    save_pending(pending)
                    print(f"Detected change: {full_path} ({ftype})")
                    has_unnotified_changes = True
                    last_change_time = time.time()
                
                # If a new directory was created, add inotify watch to it recursively
                if os.path.isdir(full_path) and (event.mask & flags.CREATE or event.mask & flags.MOVED_TO):
                    add_watches_recursive(full_path)

            # Debouncing logic
            if has_unnotified_changes and last_change_time:
                elapsed = time.time() - last_change_time
                if elapsed >= DEBOUNCE_TIME:
                    print(f"Debounce period of {DEBOUNCE_TIME}s reached. Sending notification.")
                    # Run notification in a background thread so we don't block inotify
                    threading.Thread(target=run_notification, daemon=True).start()
                    has_unnotified_changes = False
                    last_change_time = None

        except KeyboardInterrupt:
            print("Stopping Sentry Daemon.")
            break
        except Exception as e:
            print(f"Daemon error: {e}", file=sys.stderr)
            time.sleep(1)

if __name__ == "__main__":
    watch_system()
