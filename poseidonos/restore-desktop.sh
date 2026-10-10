#!/usr/bin/env bash
# Restores a snapshot made by backup-desktop.sh, then restarts the Plasma shell.
# With no argument it uses the oldest snapshot: the desktop you had before installing.
#   ./restore-desktop.sh [desktop-backup-*.tar.gz]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAP="${1:-$(ls "$HERE"/../desktop-backup-*.tar.gz 2>/dev/null | sort | head -n1)}"
[ -n "$SNAP" ] && [ -f "$SNAP" ] || { echo "usage: $0 [desktop-backup-*.tar.gz]  (no snapshot found)"; exit 1; }
echo "Restoring $SNAP"
"$HOME/.local/bin/poseidonos-crt" stop 2>/dev/null || true
rm -f "$HOME/.config/autostart/poseidonos-crt.desktop"
tar xzf "$SNAP" -C "$HOME"
echo "Restored. Restarting Plasma shell..."
(systemctl --user restart plasma-plasmashell.service 2>/dev/null || (kquitapp6 plasmashell; sleep 1; kstart plasmashell)) >/dev/null 2>&1 &
echo "Log out and back in to finish."
