#!/bin/bash
# bootstrap.sh - Fresh install restoration script for sentry/dotfiles.

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== Starting Sentry/Dotfiles Restoration from ${DOTFILES_DIR} ==="

# 1. Install uv if not available
if ! command -v uv &> /dev/null; then
    echo "Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source "$HOME/.local/bin/env"
fi

# 2. Sync python dependencies for the project
echo "Setting up Python virtual environment..."
cd "$DOTFILES_DIR"
uv sync

# 3. Create global symlink for dotfiles command
echo "Setting up global symlink for 'dotfiles' command..."
mkdir -p "$HOME/.local/bin"
ln -sf "${DOTFILES_DIR}/.venv/bin/dotfiles" "$HOME/.local/bin/dotfiles"

# 4. Install GNU Stow if not available
if ! command -v stow &> /dev/null; then
    echo "Stow not found. Attempting to install via dnf..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y stow
    else
        echo "Warning: dnf not found. Please install GNU Stow manually."
    fi
fi

# 5. Restore package lists
echo "Restoring packages..."

# DNF Packages
if [ -f "${DOTFILES_DIR}/packages/dnf.txt" ] && command -v dnf &> /dev/null; then
    echo "Installing DNF packages..."
    pkgs=$(grep -v '^#' "${DOTFILES_DIR}/packages/dnf.txt" | xargs)
    if [ -n "$pkgs" ]; then
        sudo dnf install -y $pkgs
    fi
fi

# Flatpak Packages
if [ -f "${DOTFILES_DIR}/packages/flatpak.txt" ] && command -v flatpak &> /dev/null; then
    echo "Installing Flatpak packages..."
    grep -v '^#' "${DOTFILES_DIR}/packages/flatpak.txt" | while read -r line; do
        if [ -n "$line" ]; then
            flatpak install -y flathub "$line" || true
        fi
    done
fi

# Pip Packages
if [ -f "${DOTFILES_DIR}/packages/pip.txt" ] && command -v pip &> /dev/null; then
    echo "Installing Pip packages..."
    pip install -r "${DOTFILES_DIR}/packages/pip.txt" || true
fi

# Pipx Packages
if [ -f "${DOTFILES_DIR}/packages/pipx.txt" ] && command -v pipx &> /dev/null; then
    echo "Installing Pipx packages..."
    grep -v '^#' "${DOTFILES_DIR}/packages/pipx.txt" | while read -r line; do
        if [ -n "$line" ]; then
            pipx install "$line" || true
        fi
    done
fi

# Uv Packages
if [ -f "${DOTFILES_DIR}/packages/uv.txt" ]; then
    echo "Installing UV tools..."
    grep -v '^#' "${DOTFILES_DIR}/packages/uv.txt" | while read -r line; do
        if [ -n "$line" ]; then
            uv tool install "$line" || true
        fi
    done
fi

# 6. Re-stow all configurations
echo "Restoring configurations via GNU Stow..."
if [ -d "${DOTFILES_DIR}/stow" ]; then
    find "${DOTFILES_DIR}/stow" -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
        pkg_name=$(basename "$dir")
        echo "Stowing package: $pkg_name"
        stow --adopt -d "${DOTFILES_DIR}/stow" -t "$HOME" "$pkg_name" || true
    done

    # Symlink categorized script executables into ~/.local/bin/ root for direct PATH resolution
    mkdir -p "$HOME/.local/bin"
    find "$HOME/.local/bin/rofi" "$HOME/.local/bin/sway" "$HOME/.local/bin/media" "$HOME/.local/bin/system" -maxdepth 1 -type f -o -type l 2>/dev/null | while read -r script_path; do
        ln -sf "$script_path" "$HOME/.local/bin/$(basename "$script_path")"
    done

    if command -v fc-cache &> /dev/null; then
        echo "Updating font cache..."
        fc-cache -fv || true
    fi
fi

echo "=== Sentry/Dotfiles Restoration Complete! ==="
