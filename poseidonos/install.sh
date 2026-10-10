#!/usr/bin/env bash
# PoseidonOS — phosphor CRT terminal theme for KDE Plasma 6
# Usage: ./install.sh [green|amber|blue] [--keep-layout] [--no-crt] [--panels auto|below|dodge|always]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANT=green; KEEP_LAYOUT=0; CRT=1; PANELS=
for a in "$@"; do case "$a" in
    auto|below|dodge|always) PANELS=$a;;
    --panels=*) PANELS=${a#*=};;
    green|amber|blue) VARIANT=$a;;
    --keep-layout) KEEP_LAYOUT=1;;
    --no-crt) CRT=0;;
    -h|--help) sed -n 2,3p "$0"; exit 0;;
esac; done

D="${XDG_DATA_HOME:-$HOME/.local/share}"
C="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
say() { printf '\e[1;32m>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m!\e[0m %s\n' "$*"; }

# ---- sanity ---------------------------------------------------------------------
ver=$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
[ "${ver:-0}" -ge 6 ] || { warn "Plasma 6 required (found: ${ver:-none})."; exit 1; }
for t in kwriteconfig6 plasma-apply-colorscheme plasma-apply-lookandfeel; do
    command -v $t >/dev/null || { warn "missing $t"; exit 1; }
done

# ---- backup ---------------------------------------------------------------------
BK="$D/poseidonos/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
for f in kdeglobals plasmarc kwinrc kwinrulesrc konsolerc ksplashrc kcminputrc kglobalshortcutsrc \
         plasma-org.kde.plasma.desktop-appletsrc plasmashellrc; do
    [ -f "$C/$f" ] && cp -a "$C/$f" "$BK/"
done
echo "$BK" > "$D/poseidonos/last-backup"
# the first backup ever taken (before PoseidonOS was applied) is the one uninstall restores
if [ ! -f "$D/poseidonos/original-backup" ]; then
    orig=$(ls -d "$D"/poseidonos/backup-* 2>/dev/null | sort | head -n1)
    echo "${orig:-$BK}" > "$D/poseidonos/original-backup"
fi
say "Backed up current settings to $BK"
"$HERE/backup-desktop.sh" || warn "Full desktop snapshot failed (settings backup above still exists)."

# ---- files ----------------------------------------------------------------------
mkdir -p "$D/fonts/poseidonos" "$D/color-schemes" "$D/plasma/desktoptheme" "$D/plasma/plasmoids" \
         "$D/plasma/look-and-feel" "$D/aurorae/themes" "$D/konsole" \
         "$D/poseidonos/crt" "$BIN" "$C/autostart" "$D/applications"

cp "$HERE"/fonts/*.ttf "$HERE"/fonts/OFL-*.txt "$D/fonts/poseidonos/"
fc-cache -rf >/dev/null 2>&1 || true   # full rebuild: stale caches garble VT323 after fonts move
cp "$HERE"/color-schemes/*.colors "$D/color-schemes/"
rm -rf "$D/plasma/desktoptheme/poseidonos"; cp -r "$HERE/plasma/desktoptheme/poseidonos" "$D/plasma/desktoptheme/"
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma_theme_poseidonos* "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma-svgelements-poseidonos* "${XDG_CACHE_HOME:-$HOME/.cache}"/ksvg-elements-poseidonos* 2>/dev/null || true   # drop cached old SVGs
for t in "$HERE"/aurorae/themes/*; do rm -rf "$D/aurorae/themes/$(basename "$t")"; cp -r "$t" "$D/aurorae/themes/"; done
mkdir -p "$D/plasma/wallpapers"
rm -rf "$D/plasma/wallpapers/com.poseidonos.wallpaper"; cp -r "$HERE/plasma-wallpaper/com.poseidonos.wallpaper" "$D/plasma/wallpapers/"
for p in "$HERE"/plasmoids/*; do rm -rf "$D/plasma/plasmoids/$(basename "$p")"; cp -r "$p" "$D/plasma/plasmoids/"; done
rm -rf "$D/plasma/look-and-feel/com.poseidonos.desktop"; cp -r "$HERE/look-and-feel/com.poseidonos.desktop" "$D/plasma/look-and-feel/"
cp "$HERE"/konsole/* "$D/konsole/"
mkdir -p "$D/icons/hicolor/scalable/apps"
cp "$HERE"/icons/*.svg "$D/icons/hicolor/scalable/apps/"   # launcher emblem
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/icon-cache.kcache" 2>/dev/null || true
cp "$HERE"/crt/* "$D/poseidonos/crt/"
install -m755 "$HERE"/bin/poseidonos-* "$BIN/"
mkdir -p "$C/poseidonos"
[ -f "$C/poseidonos/desktop.json" ] || cat > "$C/poseidonos/desktop.json" <<'JSON'
{
 "wallpaper": {"animate": true, "speed": 0.05, "dotSize": 2, "brightness": 0.45, "frequency": 3.0, "fps": 30,
               "showEmblem": true, "emblemSize": 0.42, "emblem": ""},
 "weather": {"location": "10001", "label": "New York, NY", "lat": 40.7506, "lon": -73.9972, "units": "F"}
}
JSON
for opt in "qmltermwidget:real shell inside the TERMLINK panel" "playerctl:RADIO now-playing panel" "checkupdates:pending-updates count (pacman-contrib)"; do
    cmd=${opt%%:*}; why=${opt#*:}
    if [ "$cmd" = qmltermwidget ]; then
        ls /usr/lib/qt6/qml/QMLTermWidget >/dev/null 2>&1 || warn "optional: sudo pacman -S qmltermwidget  ->  $why"
    else
        command -v "$cmd" >/dev/null || warn "optional: install $([ "$cmd" = checkupdates ] && echo pacman-contrib || echo "$cmd")  ->  $why"
    fi
done
command -v nvidia-smi >/dev/null || warn "nvidia-smi not found: the GPU readout will stay empty until the NVIDIA utils are installed."
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not on your PATH; the shortcuts use full paths so they still work.";; esac
say "Installed theme files"

# ---- fonts ------------------------------------------------------------------------
kw() { kwriteconfig6 "$@"; }
kw --file kdeglobals --group General --key font "Share Tech Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group General --key menuFont "Share Tech Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group General --key toolBarFont "Share Tech Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group General --key smallestReadableFont "Share Tech Mono,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group General --key fixed "VT323,15,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group WM --key activeFont "VT323,15,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
# square, crisp look: no blur, shorter animations
kw --file kwinrc --group Plugins --key blurEnabled false
kw --file kwinrc --group Plugins --key contrastEnabled false
kw --file kdeglobals --group KDE --key AnimationDurationFactor 0.5
say "Fonts set (UI: Share Tech Mono, titles/terminal: VT323)"

# ---- CRT overlay: autostart + Wayland fallback window rule -------------------------
cat > "$C/autostart/poseidonos-crt.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=PoseidonOS CRT overlay
Exec=$BIN/poseidonos-crt autostart
X-KDE-autostart-phase=2
NoDisplay=true
DESK
[ $CRT -eq 1 ] || touch "$C/poseidonos/crt-off" 2>/dev/null || { mkdir -p "$C/poseidonos"; touch "$C/poseidonos/crt-off"; }

RULE=poseidonos-crt-overlay
rules=$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)
if ! grep -q "$RULE" <<<"$rules"; then
    rules=${rules:+$rules,}$RULE
    count=$(awk -F, '{print NF}' <<<"$rules")
    kw --file kwinrulesrc --group General --key rules "$rules"
    kw --file kwinrulesrc --group General --key count "$count"
fi
for kv in "Description=PoseidonOS CRT overlay" "title=POSEIDONOS_CRT" "titlematch=1" \
          "above=true" "aboverule=2" "acceptfocus=false" "acceptfocusrule=2" \
          "skiptaskbar=true" "skiptaskbarrule=2" "skippager=true" "skippagerrule=2" \
          "skipswitcher=true" "skipswitcherrule=2" "noborder=true" "noborderrule=2" \
          "desktops=" "desktopsrule=2"; do
    kw --file kwinrulesrc --group "$RULE" --key "${kv%%=*}" "${kv#*=}"
done

# ---- global shortcuts (active after next login) ------------------------------------
mk_launcher() { # id name exec shortcut
    cat > "$D/applications/$1.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Icon=utilities-terminal
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
DESK
    kw --file kglobalshortcutsrc --group services --group "$1.desktop" --key _launch "$4"
}
mk_launcher poseidonos-crt-toggle "Toggle CRT overlay" "$BIN/poseidonos-crt toggle" "Meta+Shift+C"
mk_launcher poseidonos-phosphor-toggle "Toggle phosphor colour" "$BIN/poseidonos-theme toggle" "Meta+Shift+P"
mk_launcher poseidonos-panels-toggle "Toggle panel auto-hide" "$BIN/poseidonos-panels-toggle" "Meta+Shift+B"
say "Shortcuts: Meta+Shift+C = CRT on/off, Meta+Shift+P = cycle green/amber/blue, Meta+Shift+B = taskbar pinned / out of the way"

# ---- pinned taskbar apps: carry over the launchers from before PoseidonOS ---------------
find_launchers() {
    local f
    # 1) what is pinned right now (so re-installs keep new pins), 2) older backups
    grep -h '^launchers=' "$C/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null
    for f in $(ls -d "$D"/poseidonos/backup-* 2>/dev/null | sort); do
        [ -f "$f/plasma-org.kde.plasma.desktop-appletsrc" ] && grep -h '^launchers=' "$f/plasma-org.kde.plasma.desktop-appletsrc"
    done
    for f in $(ls "$HERE"/../desktop-backup-*.tar.gz 2>/dev/null | sort); do
        tar xzf "$f" -O .config/plasma-org.kde.plasma.desktop-appletsrc 2>/dev/null | grep -h '^launchers='
    done
    true
}
LAUNCHERS=$(find_launchers | sed 's/^launchers=//' | awk 'length > 0 { print; exit }') || true
LAYOUT="$D/plasma/look-and-feel/com.poseidonos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
if [ -n "$LAUNCHERS" ]; then
    awk -v L="${LAUNCHERS//&/\\\\&}" '{ gsub(/__LAUNCHERS__/, L); print }' "$LAYOUT" > "$LAYOUT.tmp" && mv "$LAYOUT.tmp" "$LAYOUT"
    say "Restored $(echo "$LAUNCHERS" | tr ',' '\n' | wc -l) pinned apps to the taskbar"
fi

# ---- apply ---------------------------------------------------------------------------
if [ $KEEP_LAYOUT -eq 1 ]; then
    plasma-apply-lookandfeel -a com.poseidonos.desktop >/dev/null
    say "Applied global theme (your panel layout was kept)"
else
    plasma-apply-lookandfeel -a com.poseidonos.desktop --resetLayout >/dev/null
    say "Applied global theme and panel layout"
fi
# ---- panel visibility ----------------------------------------------------------------
# The layout makes the taskbar always visible.  Replay whatever was chosen
# before (or --panels) so a re-install keeps your choice.
[ -n "$PANELS" ] && printf 'top=%s\nbottom=%s\n' "$PANELS" "$PANELS" > "$C/poseidonos/panels"
for i in $(seq 1 20); do
    dbus-send --session --dest=org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1 && break
    sleep 0.5
done
"$BIN/poseidonos-panels" restore >/dev/null 2>&1 || true
# a panel mode set on a live shell can stick (Plasma bugs 477810 / 478256), so
# bounce the shell once here: it then starts with the modes already in config
sleep 1
systemctl --user restart plasma-plasmashell.service 2>/dev/null \
    || { kquitapp6 plasmashell 2>/dev/null; sleep 1; (setsid plasmashell >/dev/null 2>&1 &); }
for i in $(seq 1 30); do
    dbus-send --session --dest=org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1 && break
    sleep 0.5
done
say "Taskbar: $(sed -n 's/^bottom=//p' "$C/poseidonos/panels" 2>/dev/null | tail -1 | grep . || echo always) (change with: poseidonos-panels always|dodge|auto)"

plasma-apply-desktoptheme poseidonos >/dev/null 2>&1 || true
# plasma-apply-desktoptheme does nothing on some builds, so write the name directly too
kwriteconfig6 --file plasmarc --group Theme --key name poseidonos 2>/dev/null || true
"$BIN/poseidonos-theme" "$VARIANT"
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
[ $CRT -eq 1 ] && "$BIN/poseidonos-crt" start || true

echo
say "Done. Log out and back in once so fonts, splash and shortcuts fully take effect."
say "Undo everything with: $HERE/uninstall.sh"
