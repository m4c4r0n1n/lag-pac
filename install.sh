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
                1) sudo /usr/bin/pacman -S --needed $CRITICAL_PKGS ;;
                2) sudo /usr/bin/pacman -Syu && touch "$LAST_UPDATE" ;;
                3) exit 0 ;;
            esac
        else
            echo "✅ Running scheduled full update"
            sudo /usr/bin/pacman -Syu && touch "$LAST_UPDATE"
        fi
        ;;
    -C|--critical)
        echo "🎮 Updating critical packages..."
        sudo /usr/bin/pacman -S --needed $CRITICAL_PKGS
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
