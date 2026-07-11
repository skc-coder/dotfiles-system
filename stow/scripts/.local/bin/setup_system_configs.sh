#!/bin/bash
# setup_system_configs.sh - Setup browser policies and install special applications.

set -e

DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../../../" && pwd)"
echo "=== Setting up Browser Policies and Special Applications ==="

# 1. Install Browser Policies
echo "Installing browser policies..."

# Firefox
sudo mkdir -p /etc/firefox/policies
sudo cp "${DOTFILES_DIR}/system/firefox_policies.json" /etc/firefox/policies/policies.json
echo "Firefox policies installed."

# Chrome / Chromium
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo cp "${DOTFILES_DIR}/system/chrome_policies.json" /etc/opt/chrome/policies/managed/policy.json
sudo mkdir -p /etc/chromium/policies/managed
sudo cp "${DOTFILES_DIR}/system/chrome_policies.json" /etc/chromium/policies/managed/policy.json
echo "Chrome and Chromium policies installed."

# Brave
sudo mkdir -p /etc/brave/policies/managed
sudo cp "${DOTFILES_DIR}/system/brave_policies.json" /etc/brave/policies/managed/policy.json
echo "Brave policies installed."


# 2. Install Special Applications (from todo.txt)
echo "Installing special applications..."

# MEGAsync
echo "Installing MEGAsync..."
if rpm -q megasync &>/dev/null; then
    echo "MEGAsync is already installed."
else
    if curl --connect-timeout 5 --max-time 5 -sI https://mega.nz/linux/repo/Fedora_44/x86_64/megasync-Fedora_44.x86_64.rpm | grep -q "200 OK"; then
        wget --connect-timeout=5 --timeout=10 -q https://mega.nz/linux/repo/Fedora_44/x86_64/megasync-Fedora_44.x86_64.rpm -O /tmp/megasync.rpm || true
    else
        wget --connect-timeout=5 --timeout=10 -q https://mega.nz/linux/repo/Fedora_43/x86_64/megasync-Fedora_43.x86_64.rpm -O /tmp/megasync.rpm || true
    fi
    
    if [ -f /tmp/megasync.rpm ]; then
        sudo dnf install -y /tmp/megasync.rpm
        rm -f /tmp/megasync.rpm
    else
        echo "Warning: Failed to download MEGAsync RPM. Skipping."
    fi
fi

# Brave Browser
echo "Installing Brave Browser..."
if ! command -v brave-browser &> /dev/null; then
    curl -fsS https://dl.brave.com/install.sh | sh
else
    echo "Brave Browser is already installed."
fi

# Visual Studio Code
echo "Installing Visual Studio Code..."
if ! command -v code &> /dev/null; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    sudo dnf check-update || true
    sudo dnf install -y code
fi

# 3. Handle Manual Installations (AppImages and manual RPMs)
MANUAL_FILE="${DOTFILES_DIR}/packages/manual_install.txt"
if [ -f "$MANUAL_FILE" ]; then
    echo ""
    echo "=== MANUAL INSTALLATIONS REQUIRED ==="
    echo "The following items must be installed manually:"
    
    # Read the file and output items
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines or comments
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi
        
        echo " - $line"
        
        # Clean the name for search query
        # Remove prefixes like "AppImage: " or "RPM: "
        clean_name=$(echo "$line" | sed -E 's/^(AppImage|RPM):[[:space:]]*//' | sed 's/\.AppImage//' | sed 's/\.rpm//' | tr ' ' '+')
        
        # Open in DuckDuckGo search query using xdg-open
        echo "   Opening download search for '$clean_name'..."
        xdg-open "https://duckduckgo.com/?q=download+${clean_name}" &>/dev/null &
        sleep 0.5 # pause slightly to avoid browser window spam issues
    done < "$MANUAL_FILE"
    echo "====================================="
fi

echo "=== System setup completed successfully! ==="
