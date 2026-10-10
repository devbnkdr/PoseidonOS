#!/usr/bin/env bash
# Quick update: refreshes the PoseidonOS widgets, wallpaper, scripts and Plasma style
# WITHOUT resetting your panels, widget positions or settings. Restarts the Plasma shell.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${XDG_DATA_HOME:-$HOME/.local/share}"
say() { printf '\e[1;32m>\e[0m %s\n' "$*"; }
for p in "$HERE"/plasmoids/*; do rm -rf "$D/plasma/plasmoids/$(basename "$p")"; cp -r "$p" "$D/plasma/plasmoids/"; done
rm -rf "$D/plasma/wallpapers/com.poseidonos.wallpaper"; cp -r "$HERE/plasma-wallpaper/com.poseidonos.wallpaper" "$D/plasma/wallpapers/"
rm -rf "$D/plasma/desktoptheme/poseidonos"; cp -r "$HERE/plasma/desktoptheme/poseidonos" "$D/plasma/desktoptheme/"
rm -rf "$D/plasma/look-and-feel/com.poseidonos.desktop"; cp -r "$HERE/look-and-feel/com.poseidonos.desktop" "$D/plasma/look-and-feel/"
mkdir -p "$D/poseidonos/crt"
cp "$HERE"/crt/* "$D/poseidonos/crt/"
install -m755 "$HERE"/bin/poseidonos-* "$HOME/.local/bin/"
# colour variants (green / amber / blue): schemes, window frames, Konsole
mkdir -p "$D/color-schemes" "$D/aurorae/themes" "$D/konsole"
cp "$HERE"/color-schemes/*.colors "$D/color-schemes/"
for t in "$HERE"/aurorae/themes/*; do rm -rf "$D/aurorae/themes/$(basename "$t")"; cp -r "$t" "$D/aurorae/themes/"; done
cp "$HERE"/konsole/* "$D/konsole/"
mkdir -p "$D/icons/hicolor/scalable/apps"
cp "$HERE"/icons/*.svg "$D/icons/hicolor/scalable/apps/"   # launcher emblem
# re-apply the current colour so every part (frames, Konsole, CRT tint) matches
V=$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/poseidonos/variant" 2>/dev/null || echo green)
"$HOME/.local/bin/poseidonos-theme" "$V" >/dev/null 2>&1 || true
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/icon-cache.kcache" "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma_theme_poseidonos* "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma-svgelements-poseidonos* "${XDG_CACHE_HOME:-$HOME/.cache}"/ksvg-elements-poseidonos* "${XDG_CACHE_HOME:-$HOME/.cache}"/plasmashell/qmlcache/* 2>/dev/null || true
# Panel visibility is set before the restart, never after: changing a panel's
# hiding mode on a running shell trips Plasma bugs 477810 / 478256 and leaves the
# bar stuck on top of every window.  A shell that starts with the mode already in
# its config comes up correctly.
"$HOME/.local/bin/poseidonos-panels" restore 2>&1 | sed 's/^/> /' || true
sleep 1
say "Files updated. Restarting Plasma shell..."
systemctl --user restart plasma-plasmashell.service 2>/dev/null || { kquitapp6 plasmashell 2>/dev/null; sleep 1; (kstart plasmashell >/dev/null 2>&1 &); }
# read-only check of what the restarted shell came up with
"$HOME/.local/bin/poseidonos-panels" status 2>&1 | sed 's/^/> /' || true
say "Done. Your layout and settings were kept."
