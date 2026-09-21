# Dotfiles System & Sway Productivity Suite

Personal Linux dotfiles, system configuration, package lists, and Sway Wayland productivity tools. Everything is tracked with Git, automated via Python (`uv`), and managed using GNU Stow for 1-command fresh laptop restoration.

---

## 🚀 Quick Setup on a New Laptop (1-Command Restoration)

When setting up a fresh Linux (Fedora / RHEL / Arch / Debian) laptop, run the single command below:

```bash
git clone https://github.com/skc-coder/dotfiles-system.git ~/dev/dotfiles
cd ~/dev/dotfiles
./bootstrap.sh
```

### What `./bootstrap.sh` Does Automatically:
1. **Installs `uv` & Python Virtualenv**: Sets up python environment and installs `dotfiles` CLI.
2. **Installs System Packages**: Automatically installs DNF, Flatpak, Pip, and UV tools from `packages/` text files.
3. **Restores Configurations via GNU Stow**: Symlinks configs (`sway`, `waybar`, `kitty`, `rofi`, `thunar`, `scripts`, `gtk`, `fonts`) into your `~/$HOME` directory.
4. **Refreshes Font Cache**: Runs `fc-cache -fv` for custom typography.

---

## ⚙️ Daily Usage & Dotfiles Maintenance

Manage your system backups and dotfiles sync effortlessly with the `dotfiles` CLI:

```bash
# Run automated full system backup (packages, configs, git repos)
uv run python dotfiles.py backup

# Re-link / update stowed configurations after modifying files
stow -R sway waybar scripts rofi kitty -d ~/dev/dotfiles/stow -t ~

# Update dotfiles repository from GitHub
git pull && ./bootstrap.sh
```

---

## ⚡ Sway Productivity Cheat Sheet & Keyboard Shortcuts

Below is the complete sitemap of productivity shortcuts configured in your Sway setup:

### 🌐 Browser & Window Management
* `Super + Shift + Space` : **Toggle & Save Floating Mode Persistently** (Floats window and saves permanent `for_window` rule so the app always launches floating).
* `Super + Ctrl + Space` : **Temporary Floating Toggle** (One-off floating mode without saving rule).
* `Super + B` / `Ctrl + B` : **Launch Default Web Browser** (Launches browser set in `~/.config/current-browser`).
* `Super + Shift + B` / `Ctrl + Shift + B` : **Browser Selector Dropdown** (Rofi GUI to switch default browser between Brave, Chromium, Firefox, etc.).

### 📁 Search, Tools & Navigation
* `Super + P` : **Smart File Search** (`~/.local/bin/rofi-file-search.sh`)
  * Fast indexing of `~/dev`, `~/Documents`, `~/Downloads`, `~/Pictures`, `~/.config`.
  * Ignores heavy folders (`.git`, `node_modules`, `venv`, `.cache`).
  * Tracks launch frequency and promotes frequently used files to the top.
* `Super + Shift + K` : **Interactive Sway Keybindings Manager** (`~/.local/bin/sway-keybindings-manager.sh`)
  * GUI popup using Rofi + Zenity to Add, Edit, or Delete Sway keybindings live.
* `Super + U` : **Floating Scratchpad Terminal** (`~/.local/bin/toggle-scratchpad-term.sh`)
  * Toggles a centered drop-down Kitty terminal overlay anywhere.
* `Super + Shift + E` : **Power & Session Menu** (`~/.local/bin/rofi-power-menu.sh`)
  * Shutdown, Reboot, Suspend, Swaylock, and Logout options.
* `Super + A` : **Audio Output Switcher** (`~/.local/bin/rofi-audio-switcher.sh`)
  * Switch default PipeWire audio output between Speakers, Headphones, or HDMI via `wpctl`.
* `Super + /` : **Quick Runner & Calculator** (`~/.local/bin/rofi-quick-runner.sh`)
  * Inline math evaluator (e.g. `250*1.18`) and quick URL/search launcher.
* `Super + .` : **Rofi Emoji & Glyph Picker** (`~/.local/bin/rofi-emoji.sh`)
  * Search and copy emojis directly to clipboard.
* `Super + Shift + V` : **VPN Toggle** (`~/.local/bin/vpn-toggle.sh`)
* `Super + Shift + W` : **Wallpaper Selector** (`~/.local/bin/wallpaper-selector.sh`)
* `Super + Shift + O` : **OCR Screenshot Tool** (`~/.local/bin/ocr_screenshot.sh`)

---

## 📦 Directory Structure & Component Overview

| Path / Folder | Purpose & Description |
| :--- | :--- |
| `bootstrap.sh` | Main 1-click restoration script for fresh laptop setups. |
| `dotfiles.py` | Python CLI for running backups, package sync, and git repo management. |
| `stow/sway/` | Sway window manager config (`~/.config/sway/config`). |
| `stow/waybar/` | Status bar config & styling (`~/.config/waybar/`). |
| `stow/rofi/` | Custom Rofi launcher theme and styles (`~/.config/rofi/`). |
| `stow/scripts/` | Executable system scripts & tools (`~/.local/bin/`). |
| `stow/kitty/` | Kitty terminal emulator configuration. |
| `stow/thunar/` | Thunar file manager custom SENTRY context menu actions. |
| `packages/` | Text lists of DNF, Flatpak, Pip, and UV installed software packages. |
| `history.md` | Chronological log of changes, updates, and feature additions. |

---

## 🛠️ Recommended CLI Tools Included

* `zoxide` (`z`): Smart directory navigation based on history (`z dev`, `z dotfiles`).
* `fzf`: Command-line fuzzy finder for files, history (`Ctrl+R`), and process filtering.
* `tldr`: Practical, simplified command cheat sheets (`tldr tar`, `tldr ffmpeg`).
* `uv`: Blazing fast Python package and virtual environment manager.
