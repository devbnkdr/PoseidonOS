#!/usr/bin/env bash
# Fixes garbled or scrambled text in the theme (a stale font cache).
set -u
D="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$D/fonts/poseidonos"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$HERE"/fonts/*.ttf "$D/fonts/poseidonos/"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/fontconfig" "${XDG_CACHE_HOME:-$HOME/.cache}"/plasmashell/qmlcache 2>/dev/null
fc-cache -rf >/dev/null 2>&1
fc-list | grep -iE "VT323|Share Tech" | sed 's/^/  font ok: /'
echo "Restarting Plasma shell..."
systemctl --user restart plasma-plasmashell.service 2>/dev/null || { kquitapp6 plasmashell; sleep 1; (kstart plasmashell >/dev/null 2>&1 &); }
echo "Done. If other apps still show scrambled text, log out and back in."
