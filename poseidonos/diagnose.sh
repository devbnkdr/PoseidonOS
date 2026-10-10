#!/usr/bin/env bash
# Collects everything useful for debugging the theme into diag.txt next to the project folder.
# Attach that file when you open an issue.
OUT="$(cd "$(dirname "$0")/.." && pwd)/diag.txt"
{
echo "== date";               date
echo "== session";            echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"; plasmashell --version 2>&1
echo "== qt qml tool";        for q in qml6 /usr/lib/qt6/bin/qml qml; do command -v $q && $q --version 2>&1 | head -1; done
echo "== QMLTermWidget";      ls -d /usr/lib/qt6/qml/QMLTermWidget /usr/lib/qt/qml/QMLTermWidget 2>&1; pacman -Q qmltermwidget 2>&1
echo "== tools";              for t in nvidia-smi playerctl checkupdates wpctl nmcli bluetoothctl kioclient konsole; do printf '%-14s %s\n' $t "$(command -v $t || echo MISSING)"; done
echo "== installed files";    ls -la ~/.local/bin/poseidonos-* 2>&1; ls ~/.local/share/plasma/plasmoids/ ~/.local/share/plasma/wallpapers/ 2>&1
echo "== stats sys";          timeout 10 ~/.local/bin/poseidonos-stats sys 2>&1 | head -c 1500; echo
echo "== stats exec test";    timeout 10 ~/.local/bin/poseidonos-stats exec "$(printf %s "$HOME" | base64 -w0)" "$(printf 'echo hello-from-termlink' | base64 -w0)" 2>&1
echo "== stats profile";      timeout 10 ~/.local/bin/poseidonos-stats profile 2>&1
echo "== crt overlay";          ~/.local/bin/poseidonos-crt status 2>&1; \
                            echo "pidfile: $(cat "${XDG_RUNTIME_DIR:-/tmp}/poseidonos-crt.pid" 2>/dev/null || echo none)"; \
                            pgrep -a -u "$(id -u)" -f 'crt/overlay-' 2>&1; \
                            ls -la ~/.local/share/poseidonos/crt/ 2>&1; \
                            echo "-- crt log --"; tail -n 40 ~/.local/share/poseidonos/poseidonos-crt.log 2>&1
echo "== layer-shell qml";     ls -d /usr/lib/qt6/qml/org/kde/layershell /usr/lib/qt/qml/org/kde/layershell 2>&1; pacman -Q layer-shell-qt 2>&1; echo "QML2_IMPORT_PATH=$QML2_IMPORT_PATH"
echo "== stray overlay windows";  timeout 5 qdbus6 org.kde.KWin /KWin 2>/dev/null | head -3; pgrep -a -u "$(id -u)" qml 2>&1
echo "== phosphor";            cat ~/.config/poseidonos/variant 2>&1; \
                            kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme 2>&1; \
                            kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>&1; \
                            kreadconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile 2>&1; \
                            echo "-- theme log --"; tail -n 20 "${XDG_CACHE_HOME:-$HOME/.cache}/poseidonos-theme.log" 2>&1
echo "== panels"
# Plasma 6 keeps panelVisibility in plasmashellrc [PlasmaViews][Panel <id>], not in the applets file
python3 - "${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc" "${XDG_CONFIG_HOME:-$HOME/.config}/plasmashellrc" <<'PYP' 2>&1
import re, sys
VIS = {"0": "always visible (reserves space)", "1": "auto hide", "2": "dodge windows", "3": "windows go below"}
LOC = {"3": "top", "4": "bottom", "5": "left", "6": "right"}
def groups(path):
    out, cur = {}, None
    try: text = open(path).read()
    except Exception as e: print("cannot read", path, e); return out
    for l in text.split("\n"):
        if l.startswith("[") and l.rstrip().endswith("]"):
            cur = l.strip(); out.setdefault(cur, {}); continue
        if cur is not None and "=" in l:
            k, v = l.split("=", 1); out[cur][k] = v
    return out
a, r = groups(sys.argv[1]), groups(sys.argv[2])
for head, d in a.items():
    m = re.match(r"^\[Containments\]\[(\d+)\]$", head)
    if not m or d.get("plugin") != "org.kde.panel": continue
    n = m.group(1)
    vis = r.get("[PlasmaViews][Panel %s]" % n, {}).get("panelVisibility", "0")
    widgets = [v.get("plugin", "?").split(".")[-1] for h, v in a.items()
               if re.match(r"^\[Containments\]\[%s\]\[Applets\]\[\d+\]$" % n, h)]
    print("panel %-4s edge=%-7s visibility=%s  widgets=%s" % (
        n, LOC.get(d.get("location"), d.get("location")), VIS.get(vis, vis), ",".join(widgets)))
PYP
echo "saved panel choice: $(cat "${XDG_CONFIG_HOME:-$HOME/.config}/poseidonos/panels" 2>/dev/null || echo '(none)')"
echo "== application crashes (last boot)"
coredumpctl list --since -1day --no-pager 2>&1 | tail -n 25
echo "== oom / gpu"
journalctl --user -b --no-pager 2>/dev/null | grep -iE 'out of memory|oom-kill|gpu hang|GPU crash|Xid|segfault|core-dump|renderer process|gpu process' | tail -n 40
dmesg 2>/dev/null | grep -iE 'oom|Xid|NVRM|segfault' | tail -n 20
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv 2>&1
echo "== qml / overlay processes"
pgrep -a -u "$(id -u)" qml 2>&1
echo "== kwin"
journalctl --user -b --no-pager -u plasma-kwin_wayland.service -u plasma-kwin_x11.service 2>/dev/null | tail -n 30
echo "== plasmashell log (theme related)"
journalctl --user -b --no-pager 2>/dev/null | grep -iE 'poseidonos|TermReal|TermConsole|QMLTermWidget|plasma5support|hud' | tail -n 80
echo "== plasmashell log (qml errors)"
journalctl --user -b --no-pager 2>/dev/null | grep -iE 'plasmashell.*(qml|error|warning)' | tail -n 40
} > "$OUT" 2>&1
echo "Wrote $OUT"
