# Dotfiles System & Sway Productivity Suite

Personal Linux dotfiles and Sway productivity suite, managed with GNU Stow and Python (`uv`).

## Setup & Installation

```bash
git clone https://github.com/skc-coder/dotfiles-system.git
cd dotfiles-system
stow -R sway waybar scripts -t ~
uv venv && source .venv/bin/activate
uv pip install -e .
```

## Running the Code

```bash
python3 dotfiles.py status
python3 dotfiles.py backup
```

## Update & Run

```bash
git pull && stow -R sway waybar scripts -t ~
```

---

## ⚡ Complete Session Feature Cheat Sheet

### 1. 📂 Smart File Search (`Super + P`)
* **Shortcut**: `Mod4 + P` (`$mod+p`)
* **Script**: `~/.local/bin/rofi-file-search.sh`
* **Features**:
  * Lightning fast file finder indexing `~/dev`, `~/Documents`, `~/Downloads`, `~/Pictures`, `~/Desktop`, `~/.config`.
  * **Excludes junk/heavy folders**: Automatically ignores `.git`, `node_modules`, `.cache`, `venv`, `target`, and `.gemini`.
  * **Smart Usage Frequency Tracker**: Tracks launch history in `~/.cache/rofi-file-search/file_freq.txt`. Using a file multiple times automatically promotes it to the top marked with `[FREQ]`.

### 2. 🛠️ Interactive Sway Shortcut Manager (`Super + Shift + K`)
* **Shortcut**: `Mod4 + Shift + K` (`$mod+Shift+k`)
* **Script**: `~/.local/bin/sway-keybindings-manager.sh`
* **Features**:
  * GUI popup using Rofi + Zenity to **Add**, **Edit/Change**, or **Delete** any Sway keybinding without opening a text editor.
  * Automatically updates `~/.config/sway/config` and reloads Sway (`swaymsg reload`) live.

### 3. 🖥️ Floating Drop-down Scratchpad Terminal (`Super + U`)
* **Shortcut**: `Mod4 + U` (`$mod+u`)
* **Script**: `~/.local/bin/toggle-scratchpad-term.sh`
* **Features**:
  * Toggles a centered floating Kitty terminal overlay from anywhere on your desktop instantly.

### 4. ⚡ Power / Session Menu (`Super + Shift + E`)
* **Shortcut**: `Mod4 + Shift + E` (`$mod+Shift+e`)
* **Script**: `~/.local/bin/rofi-power-menu.sh`
* **Features**:
  * Clean modal for `Shutdown` (top choice), `Reboot`, `Suspend`, `Lock` (swaylock), and `Logout`.

### 5. 🔊 PipeWire Audio Output Switcher (`Super + A`)
* **Shortcut**: `Mod4 + A` (`$mod+a`)
* **Script**: `~/.local/bin/rofi-audio-switcher.sh`
* **Features**:
  * Instantly switch default audio output between Laptop Speakers, Headphones, or HDMI via `wpctl`.

### 6. 🧮 Universal Quick Runner & Calculator (`Super + /`)
* **Shortcut**: `Mod4 + /` (`$mod+/`)
* **Script**: `~/.local/bin/rofi-quick-runner.sh`
* **Features**:
  * Evaluates math expressions (e.g., `250*1.18`) and copies results directly to clipboard.
  * Launches URLs or web searches directly into Brave.

### 7. 😃 Rofi Emoji & Symbol Picker (`Super + .`)
* **Shortcut**: `Mod4 + .` (`$mod+.`)
* **Script**: `~/.local/bin/rofi-emoji.sh`
* **Features**:
  * Instant emoji & glyph search with auto-copy to clipboard (`wl-copy`).

### 8. 🕒 Waybar 12-Hour Clock
* **Config**: `~/.config/waybar/config.jsonc`
* **Format**: Displayed in 12-hour AM/PM format (`Mon Aug 16, 10:54 PM`).

### 9. 🖼️ Sway 10-Second Wallpaper Slideshow
* **Script**: `~/.local/bin/wallpaper-scheduler.sh`
* **Behavior**: Runs as a daemon on Sway startup, picking random wallpapers from `~/Pictures/wallpapers` every 10 seconds.

---

## 🎁 Bonus Cool Scripts & Tool Recommendations to Make Life Easy-Peasy

1. **`zoxide` (Smart `cd`)**:
   * Installed on your system! Replaces `cd` with `z` (e.g. `z dotfiles` or `z dev`) to jump to any folder instantly based on your habits.
2. **`fzf` (Fuzzy Finder)**:
   * Installed on your system! Combine with shell history (`Ctrl+R`) or file browsing for instant terminal filtering.
3. **`tldr`**:
   * Simplified man pages. Instead of reading huge manual pages, run `tldr tar` or `tldr ffmpeg` for top practical command examples.
