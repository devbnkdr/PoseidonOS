#!/usr/bin/env bash
# Full snapshot of your current KDE Plasma desktop setup, saved next to this script.
# Restore later with:  ./restore-desktop.sh <backup file>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../desktop-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
cd "$HOME"
items=()
for f in .config/kdeglobals .config/plasmarc .config/kwinrc .config/kwinrulesrc .config/konsolerc \
         .config/ksplashrc .config/kcminputrc .config/kglobalshortcutsrc .config/khotkeysrc \
         .config/plasma-org.kde.plasma.desktop-appletsrc .config/plasmashellrc .config/kscreenlockerrc \
         .config/breezerc .config/Kvantum .config/gtk-3.0 .config/gtk-4.0 .config/autostart \
         .local/share/plasma .local/share/color-schemes .local/share/aurorae .local/share/konsole \
         .local/share/wallpapers; do
    [ -e "$f" ] && items+=("$f")
done
tar czf "$OUT" "${items[@]}"
echo "Desktop backed up to: $(realpath "$OUT")"
