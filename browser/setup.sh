#!/usr/bin/env bash
# setup.sh - Sync browser custom extensions, install policies, and configure launchers.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$DOTFILES/extensions"
POLICY_DIR="$DOTFILES/policy"

echo "=== Setting up Browser Custom Extensions and Policies ==="

# 1. Sync custom extensions
mkdir -p "$EXT_DIR"

echo "Syncing custom extensions from GitHub..."
# ytmaster
if [ -d "$EXT_DIR/ytmaster" ]; then
    echo "Updating ytmaster extension..."
    git -C "$EXT_DIR/ytmaster" pull || true
else
    echo "Cloning ytmaster extension..."
    git clone https://github.com/skc-coder/ytmaster "$EXT_DIR/ytmaster"
fi

# webtools (formerly searchfocus)
if [ -d "$EXT_DIR/webtools" ]; then
    echo "Updating webtools extension..."
    git -C "$EXT_DIR/webtools" pull || true
else
    echo "Cloning webtools extension..."
    git clone https://github.com/skc-coder/webtools "$EXT_DIR/webtools"
fi

# 2. Install managed policies (requires sudo)
echo "Installing browser policies..."

# Clean up old/conflicting policy files
sudo rm -f /etc/firefox/policies/policies.json
sudo rm -f /etc/brave/policies/managed/policies.json

# Chromium
sudo mkdir -p /etc/chromium/policies/managed
sudo cp "$POLICY_DIR/chromium-policy.json" /etc/chromium/policies/managed/policy.json
echo "Chromium policies installed."

# Google Chrome
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo cp "$POLICY_DIR/chromium-policy.json" /etc/opt/chrome/policies/managed/policy.json
echo "Google Chrome policies installed."

# Brave
sudo mkdir -p /etc/brave/policies/managed
sudo cp "$POLICY_DIR/brave-policy.json" /etc/brave/policies/managed/policy.json
echo "Brave policies installed."

# Firefox
sudo mkdir -p /usr/lib64/firefox/distribution
sudo cp "$POLICY_DIR/firefox-policies.json" /usr/lib64/firefox/distribution/policies.json
echo "Firefox policies installed."

# 3. Create launcher scripts for custom unpacked extensions
echo "Configuring custom launchers..."
mkdir -p "$HOME/.local/bin"

# Get list of all unpacked extensions
LOAD_LIST=$(find "$EXT_DIR" -mindepth 1 -maxdepth 1 -type d | paste -sd, -)

if [ -n "$LOAD_LIST" ]; then
    # Chromium custom launcher
    cat > "$HOME/.local/bin/chromium-custom" <<EOF
#!/usr/bin/env bash
# Custom Chromium launcher with unpacked extensions loaded
exec chromium --load-extension="$LOAD_LIST" "\$@"
EOF
    chmod +x "$HOME/.local/bin/chromium-custom"
    echo "Created chromium-custom launcher."

    # Brave custom launcher
    cat > "$HOME/.local/bin/brave-custom" <<EOF
#!/usr/bin/env bash
# Custom Brave launcher with unpacked extensions loaded
exec brave-browser --load-extension="$LOAD_LIST" "\$@"
EOF
    chmod +x "$HOME/.local/bin/brave-custom"
    echo "Created brave-custom launcher."
else
    echo "No custom extensions found. Skipping launcher creation."
fi

echo "=== Browser environment setup completed successfully! ==="
