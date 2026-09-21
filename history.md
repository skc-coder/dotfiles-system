# Project Change & Task History

## [2026-09-21] Sway Persistent Floating Toggle Shortcut

### User Request
- Implement a shortcut that toggles floating mode for the currently focused window and saves a persistent `for_window` rule in Sway dotfiles so it automatically launches in floating mode next time.

### Implementation Summary
1. **Created Persistence Script**:
   - Built [/home/skc/dev/dotfiles/stow/scripts/.local/bin/sway-toggle-persist-floating.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/sway-toggle-persist-floating.sh).
   - Extracts focused window `app_id` (or X11 `class`), toggles float state immediately, appends `for_window [<app_id|class>] floating enable, move position center` rule to `~/.config/sway/config`, and reloads Sway.
   - Handles toggling OFF floating persistence if triggered on an already persistent app.
2. **Configured Sway Keybinding**:
   - Updated [/home/skc/dev/dotfiles/stow/sway/.config/sway/config](file:///home/skc/dev/dotfiles/stow/sway/.config/sway/config):
     - `bindsym $mod+Shift+space exec ~/.local/bin/sway-toggle-persist-floating.sh`
     - `bindsym $mod+Ctrl+space floating toggle` (one-off temp floating toggle)
3. **Git Sync & Push**:
   - Staged, committed, and pushed changes to remote `skc-coder/dotfiles-system`.

## [2026-09-21] Rofi Dynamic Browser Selector & Sway Keybindings

### User Request
- Create simple GUI dropdown selector to quickly switch default browser (e.g. Brave vs Firefox Nightly) on Fedora Sway without manually editing Sway configuration files.

### Implementation Summary
1. **Created Rofi GUI Browser Selector Script**:
   - Created [/home/skc/dev/dotfiles/stow/scripts/.local/bin/browser-selector](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/browser-selector) to list installed browsers in Rofi dropdown and write selection to `~/.config/current-browser`.
2. **Created Launcher Wrapper Script**:
   - Created [/home/skc/dev/dotfiles/stow/scripts/.local/bin/launch-browser](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/launch-browser) to read current browser preference and execute target browser.
3. **Updated Rofi Hub**:
   - Integrated `🌐 Switch Default Browser` option into [/home/skc/dev/dotfiles/stow/scripts/.local/bin/rofi-hub.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/rofi-hub.sh).
4. **Sway Keybindings Configured**:
   - Updated [/home/skc/dev/dotfiles/stow/sway/.config/sway/config](file:///home/skc/dev/dotfiles/stow/sway/.config/sway/config):
     - `bindsym Ctrl+b exec ~/.local/bin/launch-browser` and `$mod+b exec ~/.local/bin/launch-browser`.
     - `bindsym Ctrl+Shift+b exec ~/.local/bin/browser-selector` and `$mod+Shift+b exec ~/.local/bin/browser-selector`.
5. **Git & GitHub Integration**:
   - Created GitHub Issue [#4](https://github.com/skc-coder/dotfiles-system/issues/4).

## [2026-09-20] Image to PDF Sentry Tool Implementation

### User Request
- Implement "Convert Images to PDF" Sentry Tool for Thunar file manager, and convert images in `/home/skc/Downloads/book/images/` to PDF.

### Implementation Summary
1. **Converted Target Images**:
   - Converted all 164 images in `/home/skc/Downloads/book/images/` into natural numerically sorted PDF document: [/home/skc/Downloads/book/images/converted_book.pdf](file:///home/skc/Downloads/book/images/converted_book.pdf).
2. **Sentry Tool Context Menu Action**:
   - Added `to_pdf` action handler in [/home/skc/.local/bin/image_tools.sh](file:///home/skc/.local/bin/image_tools.sh) supporting Zenity file selection, natural numerical image sorting (1, 2, ..., 10, 100), and Pillow PDF rendering.
   - Added **Convert Images to PDF** custom action in [/home/skc/.config/Thunar/uca.xml](file:///home/skc/.config/Thunar/uca.xml) under **Sentry Tools** context menu.
3. **Dotfiles Git Sync & Remote Push**:
   - Updated dotfiles source repository files [/home/skc/dev/dotfiles/stow/scripts/.local/bin/image_tools.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/image_tools.sh) and [/home/skc/dev/dotfiles/stow/thunar/.config/Thunar/uca.xml](file:///home/skc/dev/dotfiles/stow/thunar/.config/Thunar/uca.xml).
   - Committed and pushed changes to remote repository `skc-coder/dotfiles-system`.

## [2026-09-19] Custom Font Extraction, Installation, and Dotfiles Stow Integration

### User Request
- Install custom downloaded fonts from `/home/skc/Downloads/mega/` and store them in dotfiles so they persist across system reinstalls.

### Implementation Summary
1. **Extracted 13 Font Packages**:
   - Extracted font archives from `/home/skc/Downloads/mega/` (`baskervville`, `behind-the-nineties`, `cmu`, `dejavu-serif`, `eb-garamond`, `libre-baskerville`, `lora`, `merriweather`, `noto-serif`, `piston-black`, `rapunled`, `the-godfather`, `windraw-aesthetic`).
   - Cleaned up archive residue (`__MACOSX`) and structured fonts into `stow/fonts/.local/share/fonts/<Font-Name>/` (97 font files total).
2. **GNU Stow & System Font Cache Update**:
   - Linked font directories into `$HOME/.local/share/fonts/` using GNU Stow.
   - Refreshed system font cache using `fc-cache -fv`. Verified font registration via `fc-list`.
3. **Bootstrap Automation**:
   - Updated [/home/skc/dev/dotfiles/bootstrap.sh](file:///home/skc/dev/dotfiles/bootstrap.sh) to automatically run `fc-cache -fv` after stowing configs on fresh OS installations.


## [2026-09-10] Modular Windows XP (Luna Classic Blue) Theme Integration

### User Request
- Apply Windows XP colors, install XP icons, and customize Sway, Waybar, Rofi, Kitty, and GTK modularly.

### Implementation Summary
1. **Installed Theme & Icon Assets**:
   - Cloned `B00merang-Project/Windows-XP` GTK Theme into `~/.local/share/themes/Windows-XP-Luna`.
   - Cloned `B00merang-Artwork/Windows-XP` Icon Pack into `~/.local/share/icons/Windows-XP`.
   - Applied settings via `gsettings` (`GTK_THEME=Windows-XP-Luna`, `icon-theme=Windows-XP`).
2. **Modular Color Systems**:
   - **Sway Window Manager**: Created [/home/skc/dev/dotfiles/stow/sway/.config/sway/colors/xps_luna.colors](file:///home/skc/dev/dotfiles/stow/sway/.config/sway/colors/xps_luna.colors) and included it in [/home/skc/dev/dotfiles/stow/sway/.config/sway/config](file:///home/skc/dev/dotfiles/stow/sway/.config/sway/config).
   - **Waybar**: Created [/home/skc/dev/dotfiles/stow/waybar/.config/waybar/xps_luna.css](file:///home/skc/dev/dotfiles/stow/waybar/.config/waybar/xps_luna.css) and updated [/home/skc/dev/dotfiles/stow/waybar/.config/waybar/style.css](file:///home/skc/dev/dotfiles/stow/waybar/.config/waybar/style.css) with Luna taskbar gradients.
   - **Rofi Launcher**: Created [/home/skc/dev/dotfiles/stow/rofi/.config/rofi/colors/xp-luna.rasi](file:///home/skc/dev/dotfiles/stow/rofi/.config/rofi/colors/xp-luna.rasi) and updated [/home/skc/dev/dotfiles/stow/rofi/.config/rofi/config.rasi](file:///home/skc/dev/dotfiles/stow/rofi/.config/rofi/config.rasi).
   - **Kitty Terminal**: Created [/home/skc/dev/dotfiles/stow/kitty/.config/kitty/themes/xp-luna.conf](file:///home/skc/dev/dotfiles/stow/kitty/.config/kitty/themes/xp-luna.conf) and updated [/home/skc/dev/dotfiles/stow/kitty/.config/kitty/kitty.conf](file:///home/skc/dev/dotfiles/stow/kitty/.config/kitty/kitty.conf).

## [2026-09-06] Pomodoro Chime & Focus Sound Volume Reduction

### User Request
- Reduce volume of the Pomodoro transition chime and start sound as it was too loud.

### Implementation Summary
1. **Audio Volume Reduction**:
   - Modified [/home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh).
   - Reduced volume to **10%** (`--volume=0.1` / `--volume=10` / `6553`) across `pw-play`, `mpv`, `paplay`, and `ffplay` audio execution handlers for both transition chime (`play_chime`) and starting focus audio (`play_audio`).
2. **Git Commit & Sync**:
   - Committed changes and pushed to remote GitHub repository.

## [2026-08-22] Document Photo Processing & Scan Guidelines

### User Request
- Process candidate photograph to remove dark background, replace with a soft light off-white tone (not full white).
- Save image in documentation meeting standard online application document upload requirements.
- Document full scan and upload guidelines for Photograph, Signature, and Left Thumb Impression.

### Implementation Summary
1. **Photo Processing**:
   - Extracted subject using GrabCut edge blending.
   - Replaced background with a clean light off-white/light gray tone (`#F0F2F5`).
   - Resized image to `200 x 230` pixels.
   - Encoded JPEG at optimized quality to obtain `32.79 KB` (strictly inside the `20KB - 50KB` limit).
   - Saved output to [/home/skc/dev/dotfiles/docs/photo_processing/passport_photo.jpg](file:///home/skc/dev/dotfiles/docs/photo_processing/passport_photo.jpg).

2. **Documentation**:
   - Created [/home/skc/dev/dotfiles/docs/photo_processing/README.md](file:///home/skc/dev/dotfiles/docs/photo_processing/README.md) detailing all parameters for Photo (200x230, 20-50KB), Signature (140x60, 10-20KB), and Left Thumb Impression (240x240, 20-50KB, 200 DPI).

3. **Automation Scripts**:
   - Maintained Python script at [/home/skc/dev/dotfiles/docs/photo_processing/fast_process.py](file:///home/skc/dev/dotfiles/docs/photo_processing/fast_process.py) for reproducible batch runs.

## [2026-08-25] Pomodoro Waybar Tick Sound Implementation

### User Request
- Implement a ticking sound in the Waybar Pomodoro timer during active focus work sessions.

### Implementation Summary
1. **Audio Synthesis**:
   - Created auto-generating 12ms crisp mechanical click waveform (`/tmp/tick.wav`) using Python `wave` module.
2. **Pomodoro Engine Update**:
   - Modified [/home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh).
   - Added `ensure_tick_sound` and non-blocking `play_tick` function using `pw-play`/`paplay`/`aplay`.
   - Triggered `play_tick` on every 1-second status tick execution when state mode is `WORK`.

## [2026-08-26] Multi-Session Pomodoro & Universfield Chime Integration

### User Request
- Use `/home/skc/dev/universfield-attention-chime-123107.mp3` sound effect for breaks/transitions.
- Implement full multi-session standard Pomodoro workflow (4 work sessions of 25m, 5m short breaks, 30m long break after session 4).
- Display active session number in Waybar (`🎯 [1/4] 24:59`, `☕ [Rest 1] 04:59`, `🌴 [Long Rest] 29:59`).
- Automatically start next focus session after short breaks with the transition chime.

### Implementation Summary
1. **Audio Asset Storage**:
   - Copied sound file to `~/.local/share/universfield-chime.mp3` and dotfiles stow path at [stow/scripts/.local/share/universfield-chime.mp3](file:///home/skc/dev/dotfiles/stow/scripts/.local/share/universfield-chime.mp3).
2. **Pomodoro Engine Redesign**:
   - Updated [/home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh) with session cycle tracking (`MODE:END_TIME:CYCLE`).
   - Plays `play_chime` on every transition (Work start, Break start, Work resume).
   - Automatically loops through 4 Focus Sessions + 3 Short Breaks (5 min) + 1 Long Break (30 min).

3. **Systemd Delayed Autostart**:
   - Created [/home/skc/dev/dotfiles/stow/systemd/.config/systemd/user/pomodoro-autostart.service](file:///home/skc/dev/dotfiles/stow/systemd/.config/systemd/user/pomodoro-autostart.service).
   - Configured 60-second delay post-login/boot (`ExecStartPre=/usr/bin/sleep 60`) to automatically start Session 1 [1/4] with Universfield chime sound. Enabled systemd user service.

4. **Session Selection Menu**:
   - Added `cmd_menu` (Rofi launcher) and `cmd_set` (`work1..4`, `rest1..3`, `longrest`) in [/home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/pomodoro-engine.sh).
   - Updated Waybar config [config.jsonc](file:///home/skc/dev/dotfiles/stow/waybar/.config/waybar/config.jsonc): **Right-click** on Waybar Pomodoro triggers `swaymsg exec /home/skc/.local/bin/pomodoro-engine.sh menu` to spawn Rofi smoothly within Sway compositor context.

## [2026-08-30] Offline Screenshot-to-Text OCR Enhancement

### User Request
- Improve simple offline screenshot-to-text OCR extraction accuracy.

### Implementation Summary
1. **Image Pre-processing**:
   - Modified [/home/skc/dev/dotfiles/stow/scripts/.local/bin/ocr_screenshot.sh](file:///home/skc/dev/dotfiles/stow/scripts/.local/bin/ocr_screenshot.sh) using ImageMagick (`convert`).
   - Added automatic 200% upscaling, contrast normalization (`-contrast-stretch 0.15x0.05%`), grayscale conversion (`-colorspace Gray`), and edge sharpening (`-sharpen 0x1`).
2. **Multi-PSM Fallback Loop**:
   - Configured fallback across Tesseract Page Segmentation Modes: `PSM 6` (uniform block of text), `PSM 3` (fully automatic page segmentation), and `PSM 11` (sparse text).

## [2026-09-03] Pomodoro Sway Login Autostart Integration

### User Request
- Ensure Pomodoro timer automatically starts immediately upon logging in.

### Implementation Summary
1. **Sway Startup Direct Execution**:
   - Updated Sway config [/home/skc/dev/dotfiles/stow/sway/.config/sway/config](file:///home/skc/dev/dotfiles/stow/sway/.config/sway/config) to include `exec ~/.local/bin/pomodoro-engine.sh start` under startup apps.
   - Disabled redundant/timing-out systemd user service `pomodoro-autostart.service`.
2. **Git Tracking & Remote Sync**:

## [2026-09-16] System Audio Issues & Pomodoro Background Loop Cleanup

### User Request
- Fix system sound issues caused by background Pomodoro timer audio processes.

### Implementation Summary
1. **Root Cause Analysis**:
   - Identified background `grep` tasks and an active Pomodoro timer state triggering background audio process loops (`pw-play` / `paplay`) while playing `/home/skc/.local/share/pomodoro-timer.mp3`.
   - PID tracker file `/tmp/pomodoro_audio.pid` had active background audio instances remaining alive.

2. **System Audio Recovery**:
   - Stopped Pomodoro timer engine state (`/home/skc/.local/bin/pomodoro-engine.sh stop`).
   - Cleaned up lingering audio processes and `/tmp/pomodoro_*` state files.
   - Tested PipeWire audio output via `pw-play` to ensure full system audio clarity and volume level.

   - Committed changes and pushed to remote GitHub repository (`main` branch).

