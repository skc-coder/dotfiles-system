# Project Change & Task History

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

## [2026-08-26] Make Vimium Policy Optional Across Browsers

### User Request
- Change Vimium policy mode in Chrome, Brave, and Firefox so that Vimium is optional (`normal_installed`) rather than forced, allowing standard uninstallation.

### Implementation Summary
1. **Policy File Updates**:
   - Updated [browser/policy/brave-policy.json](file:///home/skc/dev/dotfiles/browser/policy/brave-policy.json) and [system/brave_policies.json](file:///home/skc/dev/dotfiles/system/brave_policies.json): changed `hfjngjjnngpljjlppgbbgkhfnhhphjhk` from `force_installed` to `normal_installed`.
   - Updated [browser/policy/chromium-policy.json](file:///home/skc/dev/dotfiles/browser/policy/chromium-policy.json) and [system/chrome_policies.json](file:///home/skc/dev/dotfiles/system/chrome_policies.json): changed `hfjngjjnngpljjlppgbbgkhfnhhphjhk` from `force_installed` to `normal_installed`.
   - Updated [browser/policy/firefox-policies.json](file:///home/skc/dev/dotfiles/browser/policy/firefox-policies.json) and [system/firefox_policies.json](file:///home/skc/dev/dotfiles/system/firefox_policies.json): changed `vimium-c@gdh1995.cn` from `force_installed` to `normal_installed`.
2. **Git & Remote Push**:
   - Committed changes with message `feat(browser): update Vimium policies to normal_installed (optional)`.
   - Pushed changes directly to GitHub remote repository (`main -> main`).
