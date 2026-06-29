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
        stow -d "${DOTFILES_DIR}/stow" -t "$HOME" "$pkg_name" || true
    done
fi

# 7. Restore system files
echo "Restoring system files..."
# Hosts
if [ -f "${DOTFILES_DIR}/system/hosts" ]; then
    echo "Restoring /etc/hosts (requires sudo)..."
    sudo cp "${DOTFILES_DIR}/system/hosts" /etc/hosts
fi

# Mimeapps
if [ -f "${DOTFILES_DIR}/system/mimeapps.list" ]; then
    echo "Restoring mimeapps.list..."
    mkdir -p "$HOME/.config"
    cp "${DOTFILES_DIR}/system/mimeapps.list" "$HOME/.config/mimeapps.list"
fi

# Crontab
if [ -f "${DOTFILES_DIR}/system/crontab" ] && command -v crontab &> /dev/null; then
    echo "Restoring crontab..."
    crontab "${DOTFILES_DIR}/system/crontab" || true
fi

# 8. Clone listed Git repos
if [ -f "${DOTFILES_DIR}/repos/install.txt" ]; then
    echo "Cloning repositories..."
    grep -v '^#' "${DOTFILES_DIR}/repos/install.txt" | while read -r line; do
        if [ -n "$line" ]; then
            # Format: <repo_url> <target_dir>
            repo_url=$(echo "$line" | awk '{print $1}')
            target_dir=$(echo "$line" | awk '{print $2}')
            # Expand target dir if it contains ~
            target_dir="${target_dir/\~/$HOME}"
            if [ -n "$repo_url" ] && [ -n "$target_dir" ] && [ ! -d "$target_dir" ]; then
                echo "Cloning $repo_url to $target_dir"
                mkdir -p "$(dirname "$target_dir")"
                git clone "$repo_url" "$target_dir" || true
            fi
        fi
    done
fi

# 9. Register systemd user services
echo "Registering systemd user services..."
mkdir -p "$HOME/.config/systemd/user"
if [ -d "${DOTFILES_DIR}/system" ]; then
    find "${DOTFILES_DIR}/system" -maxdepth 1 -name "*.service" -o -name "*.timer" | while read -r unit; do
        cp "$unit" "$HOME/.config/systemd/user/"
    done
    systemctl --user daemon-reload || true
    
    # Enable and start daemon services if units were copied
    if [ -f "$HOME/.config/systemd/user/dotfiles-daemon.service" ]; then
        systemctl --user enable --now dotfiles-daemon.service || true
    fi
    if [ -f "$HOME/.config/systemd/user/dotfiles-dev-watcher.service" ]; then
        systemctl --user enable --now dotfiles-dev-watcher.service || true
    fi
    if [ -f "$HOME/.config/systemd/user/dotfiles-backup.timer" ]; then
        systemctl --user enable --now dotfiles-backup.timer || true
    fi
fi

# 10. Automatically append shell hooks to shell profiles
echo "Adding shell hooks to profile configurations..."
hook_line="source ${DOTFILES_DIR}/shell_hooks.sh"

for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc_file" ]; then
        if ! grep -Fxq "$hook_line" "$rc_file"; then
            echo "" >> "$rc_file"
            echo "# Sentry package tracking hook" >> "$rc_file"
            echo "$hook_line" >> "$rc_file"
            echo "Appended shell hooks to $rc_file"
        else
            echo "Shell hooks already configured in $rc_file"
        fi
    fi
done

# 11. Restore browser policies and special applications
if [ -f "${DOTFILES_DIR}/scripts/setup_system_configs.sh" ]; then
    echo "Running system configurations and special application installs..."
    bash "${DOTFILES_DIR}/scripts/setup_system_configs.sh"
fi

echo "=== Sentry/Dotfiles Restoration completed successfully! ==="
