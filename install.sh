#!/bin/bash
# Stable Pac Installer

set -e

echo "📦 Installing Stable Pac Update Manager..."
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "❌ Don't run as root. Run as normal user (sudo will be used when needed)"
    exit 1
fi

# Create pac script
echo "Creating pac command..."
sudo tee /usr/local/bin/pac > /dev/null << 'PACSCRIPT'
#!/bin/bash
CRITICAL_PKGS="firefox chromium steam wine-staging proton vulkan-icd-loader mesa lib32-mesa lib32-vulkan-icd-loader"
CACHE_DIR="/var/cache/safepac"
UPDATE_INTERVAL=14

mkdir -p "$CACHE_DIR" 2>/dev/null || true
LAST_UPDATE="$CACHE_DIR/last_update"

if [ -f "$LAST_UPDATE" ]; then
    DAYS_SINCE=$(( ($(date +%s) - $(date -r "$LAST_UPDATE" +%s)) / 86400 ))
else
    DAYS_SINCE=999
fi

update_critical() {
    echo "🎮 Detecting and updating critical packages..."
    echo ""

    # Update native pacman packages
    echo "📦 Checking pacman packages..."
    sudo /usr/bin/pacman -S --needed $CRITICAL_PKGS

    # Update Flatpak if installed
    if command -v flatpak &> /dev/null; then
        echo ""
        echo "📦 Checking Flatpak packages..."
        FLATPAK_APPS=(
            "org.mozilla.firefox"
            "com.google.Chrome"
            "org.chromium.Chromium"
            "com.valvesoftware.Steam"
            "org.winehq.Wine"
        )

        for app in "${FLATPAK_APPS[@]}"; do
            if flatpak list --app | grep -q "$app"; then
                echo "  Updating: $app"
                flatpak update -y "$app" 2>/dev/null || true
            fi
        done
    fi

    # Update Snap if installed
    if command -v snap &> /dev/null; then
        echo ""
        echo "📦 Checking Snap packages..."
        SNAP_APPS=("firefox" "chromium" "steam")

        for app in "${SNAP_APPS[@]}"; do
            if snap list 2>/dev/null | grep -q "^$app "; then
                echo "  Updating: $app"
                sudo snap refresh "$app" 2>/dev/null || true
            fi
        done
    fi

    # Update via yay/paru if available (AUR)
    if command -v yay &> /dev/null; then
        echo ""
        echo "📦 Checking AUR packages (yay)..."
        yay -S --needed $CRITICAL_PKGS --noconfirm 2>/dev/null || true
    elif command -v paru &> /dev/null; then
        echo ""
        echo "📦 Checking AUR packages (paru)..."
        paru -S --needed $CRITICAL_PKGS --noconfirm 2>/dev/null || true
    fi

    echo ""
    echo "✅ Critical package update complete!"
}

case "$1" in
    -U|--update)
        if [ $DAYS_SINCE -lt $UPDATE_INTERVAL ]; then
            echo "⏳ Last update: $DAYS_SINCE days ago"
            echo "⚠️  Full updates scheduled every $UPDATE_INTERVAL days"
            echo ""
            echo "1. Critical only (browser/gaming)"
            echo "2. Force full update"
            echo "3. Cancel"
            read -p "Choice: " choice

            case $choice in
                1) update_critical ;;
                2) sudo /usr/bin/pacman -Syu && touch "$LAST_UPDATE" ;;
                3) exit 0 ;;
            esac
        else
            echo "✅ Running scheduled full update"
            sudo /usr/bin/pacman -Syu && touch "$LAST_UPDATE"
        fi
        ;;
    -C|--critical)
        update_critical
        ;;
    *)
        echo "Stable Pac - Arch Update Manager"
        echo ""
        echo "Usage: pac [OPTION]"
        echo ""
        echo "Options:"
        echo "  -U, --update     Smart system update (14-day schedule)"
        echo "  -C, --critical   Update critical packages only"
        echo ""
        echo "Critical packages: Firefox, Chromium, Steam, Wine, Vulkan, Mesa"
        echo "Supports: pacman, Flatpak, Snap, AUR (yay/paru)"
        ;;
esac
PACSCRIPT

# Make executable
sudo chmod +x /usr/local/bin/pac

# Create cache directory
sudo mkdir -p /var/cache/safepac
sudo chown $USER:$USER /var/cache/safepac

echo ""
echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  pac -U    Update system (respects 14-day schedule)"
echo "  pac -C    Update critical packages anytime"
echo ""
echo "Test it now with: pac -U"
