// PoseidonOS - default layout
//  One bar at the bottom:
//    [emblem] [pinned + running apps ......] | [TERMINAL] [ CFG ] [tray] [clock] [show desktop]
//  The launcher is just the PoseidonOS emblem (no label); it opens the app menu.
//  Desktop: animated wallpaper with the HUD down the left-hand side.

var unit = gridUnit || 18;
var LAUNCHERS = "__LAUNCHERS__";

function cfg(widget, group, values) {
    widget.currentConfigGroup = group;
    for (var k in values) widget.writeConfig(k, values[k]);
}
// Square edges, always visible ("none" is Plasma's "Always Visible").
// poseidonos-panels changes this live (always / dodge / auto / below) and
// install.sh replays that choice after this layout runs.
var PANEL_HIDING = "none";
function flat(panel) {
    try { panel.floating = false; } catch (e) {}
    try { panel.hiding = PANEL_HIDING; } catch (e) {}
}

// ---- the bar (bottom) ---------------------------------------------------------
// The launcher on the left with your apps right next to it; TERMINAL, [ CFG ],
// the tray and the clock on the right, show-desktop in the corner.
// (poseidonos-panels arrange puts an existing bar back into this order.)
var bar = new Panel;
bar.location = "bottom";
bar.height = Math.round(unit * 2.6);
flat(bar);

var launcher = bar.addWidget("org.kde.plasma.kickoff");
// poseidonos-emblem-symbolic is installed into the hicolor icon theme by install.sh; being a
// "-symbolic" icon, Plasma paints it in the phosphor colour like the rest of the bar
cfg(launcher, ["General"], { icon: "poseidonos-emblem-symbolic", menuLabel: "", alphaSort: true });
var tasks = bar.addWidget("org.kde.plasma.icontasks");
if (LAUNCHERS.length && LAUNCHERS.indexOf("__") !== 0)
    cfg(tasks, ["General"], { launchers: LAUNCHERS });
bar.addWidget("org.kde.plasma.marginsseparator");
bar.addWidget("com.poseidonos.tabs");
bar.addWidget("com.poseidonos.settings");
bar.addWidget("org.kde.plasma.systemtray");
var clock = bar.addWidget("org.kde.plasma.digitalclock");
cfg(clock, ["Appearance"], {
    showDate: true, dateDisplayFormat: "BesideTime", dateFormat: "custom", customDateFormat: "yyyy.MM.dd",
    use24hFormat: 0, showSeconds: 0, autoFontAndSize: false, fontFamily: "VT323",
    fontSize: Math.round(unit * 1.1), fontWeight: 400
});
bar.addWidget("org.kde.plasma.showdesktop");

// ---- desktop: wallpaper + one unified HUD ----------------------------------------
// The HUD covers the free desktop area (from the top edge down to the copyright line)
// and lays itself out in as many columns as fit, with the TERMLINK terminal underneath.
var ds = desktops();
for (var i = 0; i < ds.length; i++) {
    var d = ds[i];
    d.wallpaperPlugin = "com.poseidonos.wallpaper";
    if (i !== 0) continue;
    var g = screenGeometry(d.screen);
    var mx = Math.round(unit * 1.8);
    var y = mx;                      // a margin below the top edge of the screen
    var footer = Math.round(g.height * 0.075 + g.height / 42 * 1.6);   // keeps the wallpaper's footer line visible
    // footer already clears the taskbar, so only keep a small breathing gap at the bottom
    var h = g.height - y - footer - Math.round(unit * 1.8);
    // left-hand side only: ~45% of the screen, capped so ultrawides keep plenty of free desktop
    var w = Math.min(Math.round(g.width * 0.45), Math.round(unit * 64));
    var hud = d.addWidget("com.poseidonos.hud", mx, y, w, h);
    cfg(hud, ["General"], { gridSections: "profile,weather,clock|vitals,net,procs|disks,files", gridCompact: "profile,vitals,disks,files,weather", bottomSections: "apps", solidBlock: false, terminal: true });
}
