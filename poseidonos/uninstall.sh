#!/usr/bin/env bash
# Restores the settings backed up by install.sh and removes PoseidonOS files.
set -uo pipefail
D="${XDG_DATA_HOME:-$HOME/.local/share}"; C="${XDG_CONFIG_HOME:-$HOME/.config}"
"$HOME/.local/bin/poseidonos-crt" stop 2>/dev/null
BK=$(cat "$D/poseidonos/original-backup" 2>/dev/null || cat "$D/poseidonos/last-backup" 2>/dev/null || true)
if [ -n "$BK" ] && [ -d "$BK" ]; then
    echo "Restoring settings from $BK"
    cp -a "$BK"/. "$C/"
else
    echo "No backup found; falling back to Breeze Dark."
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop
fi
rm -rf "$D/plasma/desktoptheme/poseidonos" "$D/plasma/look-and-feel/com.poseidonos.desktop" \
       "$D/plasma/plasmoids/com.poseidonos."* "$D/plasma/wallpapers/com.poseidonos.wallpaper" "$D/aurorae/themes/PoseidonOS-"* \
       "$D/color-schemes/PoseidonOS"*.colors "$D/konsole/PoseidonOS-"* \
       "$D/poseidonos/crt" "$C/autostart/poseidonos-crt.desktop" \
       "$D/applications/poseidonos-"*.desktop "$HOME/.local/bin/poseidonos-"* \
       "$D/icons/hicolor/scalable/apps/poseidonos-"*.svg \
       "$C/poseidonos"
echo "Fonts left in $D/fonts/poseidonos (delete if unwanted). Backups kept in $D/poseidonos/."
echo "Restarting Plasma shell..."
(systemctl --user restart plasma-plasmashell.service 2>/dev/null || (kquitapp6 plasmashell; sleep 1; kstart plasmashell)) >/dev/null 2>&1 &
echo "Log out and back in to finish restoring."
