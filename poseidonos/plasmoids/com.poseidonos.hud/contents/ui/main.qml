import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls as QQC2
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    function splitList(v) { return v.split(/[,|]/).map(s => s.trim()).filter(s => s.length && s !== "apps"); }
    readonly property var sections: splitList(Plasmoid.configuration.gridSections)
    // "a,b|c|d,e" = fixed columns (used when that many columns fit)
    readonly property var pinnedCols: Plasmoid.configuration.gridSections.indexOf("|") >= 0
        ? Plasmoid.configuration.gridSections.split("|").map(g => splitList(g)) : []
    readonly property var compact: splitList(Plasmoid.configuration.gridCompact)
    readonly property var bottomSections: Plasmoid.configuration.bottomSections.split(",").map(s => s.trim()).filter(s => s.length)
    function has(s) {
        return sections.indexOf(s) >= 0 || compact.indexOf(s) >= 0 || bottomSections.indexOf(s) >= 0;
    }
    readonly property string bin: "\"$HOME/.local/bin/poseidonos-stats\""
    // polling pauses while a maximized / fullscreen window hides the desktop,
    // and the section-only feeds also pause while the terminal is expanded over them
    CoverWatch { id: cover; active: root.cfg.pauseWhenCovered !== false }
    readonly property bool live: !cover.covered
    readonly property bool sectionsShown: live && !(Plasmoid.configuration.terminal && Plasmoid.configuration.termExpanded)
    readonly property color phosphor: Kirigami.Theme.textColor
    readonly property color bg: Kirigami.Theme.backgroundColor
    property real fitScale: 1.0      // shrinks the text so everything (plus the terminal) fits on screen
    readonly property int fpx: Math.max(11, Math.round(Plasmoid.configuration.fontSize * fitScale))

    // ---------------------------------------------------------------- data
    property var cfg: ({})
    property var sys: null
    property var prevSys: null
    property real cpuUse: 0
    property var cpuHist: []
    property var gpuHist: []
    property var ioRates: []      // [{name, rd, wr, busy}] bytes/s, %
    property var procs: []
    property var weather: null
    property string weatherErr: ""
    property bool cfgLoaded: false
    property var netRate: ({ rx: 0, tx: 0 })
    property var netHist: []
    property var info: null
    property var media: null
    property string notes: ""
    property bool notesLoaded: false
    property var profile: null
    property int appPage: 0
    readonly property bool solid: Plasmoid.configuration.solidBlock
    property var allApps: []
    property var pinnedIds: []
    property string appQuery: ""
    property date now: new Date()
    Timer { interval: 1000; running: root.live; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    function b64(str) {   // UTF-8 safe base64 (b64(string) is deprecated)
        var u = unescape(encodeURIComponent(str)), a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", o = "";
        for (var i = 0; i < u.length; i += 3) {
            var c1 = u.charCodeAt(i), c2 = u.charCodeAt(i + 1), c3 = u.charCodeAt(i + 2);
            var n = (c1 << 16) | ((c2 || 0) << 8) | (c3 || 0);
            o += a[(n >> 18) & 63] + a[(n >> 12) & 63] + (i + 1 < u.length ? a[(n >> 6) & 63] : "=") + (i + 2 < u.length ? a[n & 63] : "=");
        }
        return o;
    }
    function pushHist(arr, v) { var a = arr.slice(-59); a.push(v); return a; }

    P5Support.DataSource {
        id: sysSrc
        engine: "executable"
        connectedSources: root.sectionsShown ? [root.bin + " sys"] : []
        interval: 2000
        onNewData: (source, data) => {
            var s;
            try { s = JSON.parse(data.stdout); } catch (e) { return; }
            var p = root.sys;
            if (p) {
                var dt = s.cpu.total - p.cpu.total;
                if (dt > 0) root.cpuUse = Math.max(0, Math.min(1, 1 - (s.cpu.idle - p.cpu.idle) / dt));
                var secs = Math.max(0.1, s.t - p.t), rates = [];
                for (var i = 0; i < s.io.length; i++) {
                    var d = s.io[i], q = p.io.find(x => x.name === d.name);
                    if (!q) continue;
                    rates.push({ name: d.name, rd: (d.rd - q.rd) * 512 / secs, wr: (d.wr - q.wr) * 512 / secs,
                                 busy: Math.min(100, (d.busy - q.busy) / (secs * 10)) });
                }
                root.ioRates = rates;
                if (s.net && p.net && s.net.if === p.net.if) {
                    root.netRate = { rx: Math.max(0, (s.net.rx - p.net.rx) / secs), tx: Math.max(0, (s.net.tx - p.net.tx) / secs) };
                    root.netHist = root.pushHist(root.netHist, root.netRate.rx);
                }
            }
            root.sys = s;
            root.cpuHist = root.pushHist(root.cpuHist, root.cpuUse);
            if (s.gpu && s.gpu.util !== null) root.gpuHist = root.pushHist(root.gpuHist, s.gpu.util / 100);
        }
    }
    P5Support.DataSource {
        engine: "executable"
        connectedSources: root.sectionsShown && root.has("procs") ? [root.bin + " procs"] : []
        interval: 6000
        onNewData: (source, data) => {
            try { root.procs = JSON.parse(data.stdout).filter(p => p.cmd !== "top" && p.cmd !== "poseidonos-stats"); } catch (e) {}
        }
    }
    readonly property string cfgCmd: "cat \"$HOME/.config/poseidonos/desktop.json\" 2>/dev/null #hud"
    ConfigWatch { onChanged: { cfgSrc.disconnectSource(root.cfgCmd); cfgSrc.connectSource(root.cfgCmd); } }
    P5Support.DataSource {
        id: cfgSrc
        engine: "executable"
        connectedSources: [root.cfgCmd]
        interval: 60000     // safety net; ConfigWatch triggers a re-read on every save
        onNewData: (source, data) => {
            try {
                var o = JSON.parse(data.stdout);
                var old = JSON.stringify(root.cfg.weather || {});
                root.cfg = o;
                var first = !root.cfgLoaded;
                root.cfgLoaded = true;
                if (first || JSON.stringify(o.weather || {}) !== old) root.fetchWeather();
            } catch (e) {}
        }
    }
    function groupOf(cats, a) {
        var hay = a ? (a.name + " " + a.id + " " + (a.exec || "") + " " + (a.generic || "")).toLowerCase() : "";
        if (/parsec|remmina|rustdesk|anydesk|teamviewer|moonlight|sunshine|krdc|krfb|nomachine|virt-manager|virtual machine|vnc|x2go|kdeconnect|kde connect|remote|\bssh\b|putty|filezilla|waypipe|steamlink|steam link/.test(hay)) return "REMOTE";
        if (/chatgpt|openai|ollama|lm ?studio|lmstudio|gpt4all|jan\.ai|(^| )jan( |$)|comfy|stable.?diffusion|automatic1111|invokeai|open.?webui|llama|kobold|text-generation|oobabooga|whisper|perplexity|gemini|copilot|msty|anythingllm|alpaca|\bai\b/.test(hay)) return "AI";
        if (/steam:\/\/|lutris|heroic|gamescope|prismlauncher|curseforge|minecraft|retroarch|dolphin-emu|pcsx|rpcs3|yuzu|ryujinx|wine.*\.exe|bottles/.test(hay)) return "GAMES";
        if (/\bcode\b|\bcursor\b|\bzed\b|jetbrains|intellij|pycharm|clion|webstorm|android.?studio|godot|\bunity\b|unreal|\bgit\b|github|gitkraken|postman|dbeaver|docker|podman/.test(hay) && !/(^|;)Game(;|$)/.test(cats)) {
            if (/(^|;)Development(;|$)/.test(cats) || !cats) return "DEV";
        }
        var g = [["GAMES", /(^|;)Game(;|$)/], ["WEB", /(^|;)Network(;|$)/], ["MEDIA", /(^|;)(AudioVideo|Audio|Video)(;|$)/],
                 ["GFX", /(^|;)Graphics(;|$)/], ["OFFICE", /(^|;)(Office|Education|Science)(;|$)/], ["DEV", /(^|;)Development(;|$)/],
                 ["SYS", /(^|;)(System|Settings)(;|$)/], ["UTIL", /(^|;)Utility(;|$)/]];
        for (var i = 0; i < g.length; i++) if (g[i][1].test(cats)) return g[i][0];
        return "OTHER";
    }
    P5Support.DataSource {
        engine: "executable"
        connectedSources: root.has("apps") ? [root.bin + " allapps #hud", root.bin + " launchers #hud"] : []
        interval: 300000
        onNewData: (source, data) => {
            if (source.indexOf(" launchers") > 0) {
                root.pinnedIds = data.stdout.trim().split(",").map(x => x.replace(/^applications:/, "").replace(/^file:\/\/.*\//, "")).filter(x => x.length);
                return;
            }
            try {
                var list = JSON.parse(data.stdout);
                list.forEach(a => a.group = root.groupOf(a.cats, a));
                list.sort((a, b) => a.name.localeCompare(b.name));
                root.allApps = list;
            } catch (e) {}
        }
    }
    P5Support.DataSource {
        engine: "executable"
        connectedSources: root.has("net") || root.has("profile") ? [root.bin + " info"] : []
        interval: 60000
        onNewData: (source, data) => { try { root.info = JSON.parse(data.stdout); } catch (e) {} }
    }
    P5Support.DataSource {
        engine: "executable"
        connectedSources: root.live && root.has("media") ? [root.bin + " media"] : []
        interval: 3000
        onNewData: (source, data) => { try { root.media = JSON.parse(data.stdout); } catch (e) {} }
    }
    P5Support.DataSource {
        id: profSrc
        engine: "executable"
        connectedSources: root.live && root.has("profile") ? [root.bin + " profile"] : []
        interval: 10000
        onNewData: (source, data) => { try { root.profile = JSON.parse(data.stdout); } catch (e) {} }
    }
    // phosphor + CRT are slow, session-wide operations; a second click while one is
    // in flight only piles more work on the desktop, so they are locked out briefly
    property bool switching: false
    Timer { id: switchGuard; interval: 1500; onTriggered: root.switching = false }

    function ctl(action, arg) {
        if ((action === "phosphor" || action === "crt") ) {
            if (root.switching) return;
            root.switching = true;
            switchGuard.restart();
        }
        sh(bin + " ctl " + action + (arg !== undefined ? " " + arg : ""));
        profRefresh.restart();
    }
    // re-read the real state a few times: detached work lands a second or two later
    Timer {
        id: profRefresh; interval: 900; repeat: true; property int left: 0
        onRunningChanged: if (running) left = 4
        onTriggered: {
            profSrc.disconnectSource(root.bin + " profile");
            profSrc.connectSource(root.bin + " profile");
            if (--left <= 0) stop();
        }
    }

    P5Support.DataSource {
        id: notesSrc
        engine: "executable"
        connectedSources: root.has("notes") ? ["cat \"$HOME/.config/poseidonos/notes.txt\" 2>/dev/null; echo"] : []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (!root.notesLoaded) { root.notes = data.stdout.replace(/\n$/, ""); root.notesLoaded = true; }
        }
    }
    Timer { id: notesSave; interval: 800; onTriggered: root.sh("mkdir -p \"$HOME/.config/poseidonos\" && echo '" + b64(root.notes) + "' | base64 -d > \"$HOME/.config/poseidonos/notes.txt\"") }
    function sh(cmd) { runner.connectSource(cmd + " #" + Date.now() + Math.random()); }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    function launch(file) { runner.connectSource(bin + " launch '" + file.replace(/'/g, "") + "' #" + Date.now()); }

    // ---------------------------------------------------------------- weather (open-meteo, no key)
    function wmo(c) {
        if (c === 0) return "CLEAR";
        if (c <= 2) return "PARTLY CLOUDY";
        if (c === 3) return "OVERCAST";
        if (c === 45 || c === 48) return "FOG";
        if (c >= 51 && c <= 57) return "DRIZZLE";
        if (c >= 61 && c <= 67) return "RAIN";
        if (c >= 71 && c <= 77) return "SNOW";
        if (c >= 80 && c <= 82) return "SHOWERS";
        if (c === 85 || c === 86) return "SNOW SHOWERS";
        if (c >= 95) return "THUNDERSTORM";
        return "--";
    }
    function glyph(c) {
        if (c === 0) return "SUN";
        if (c <= 2) return "P.CLD";
        if (c === 3) return "CLOUD";
        if (c === 45 || c === 48) return "FOG";
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "SNOW";
        if (c >= 95) return "STORM";
        if (c >= 51) return "RAIN";
        return "--";
    }
    function fetchWeather() {
        if (!has("weather")) return;
        var w = cfg.weather || {};
        if (!cfgLoaded) return;
        if (w.lat === undefined || w.lon === undefined) { weatherErr = "SET LOCATION IN [ CFG ]"; return; }
        var c = w.units === "C";
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + w.lat + "&longitude=" + w.lon
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&temperature_unit=" + (c ? "celsius" : "fahrenheit") + "&wind_speed_unit=" + (c ? "kmh" : "mph")
            + "&timezone=auto&forecast_days=4";
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status === 200) {
                try { root.weather = JSON.parse(x.responseText); root.weatherErr = ""; } catch (e) { root.weatherErr = "BAD RESPONSE"; }
            } else root.weatherErr = "UPLINK OFFLINE";
        };
        x.open("GET", url);
        x.send();
    }
    Timer { interval: 15 * 60 * 1000; running: root.has("weather"); repeat: true; onTriggered: root.fetchWeather() }

    // ---------------------------------------------------------------- helpers
    function gb(bytes) { var g = bytes / 1073741824; return g >= 10 ? Math.round(g).toString() : g.toFixed(1); }
    function rate(b) {
        if (b >= 1000000) return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024) return (b / 1024).toFixed(0) + " KB/s";
        return "0 KB/s";
    }
    function pct(v) { return (v === null || v === undefined || isNaN(v)) ? "--" : Math.round(v) + "%"; }

    // ---------------------------------------------------------------- visuals
    component T: Text {
        color: root.phosphor
        font.family: "VT323"
        font.pixelSize: root.fpx
        elide: Text.ElideRight
    }
    component Bar: Item {
        id: bar
        property real value: 0      // 0..1
        property bool warn: false
        Layout.fillWidth: true
        implicitHeight: Math.round(root.fpx * 0.55)
        Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.phosphor; border.width: 1; opacity: 0.8 }
        Rectangle {
            x: 2; y: 2; height: parent.height - 4
            width: Math.max(0, (parent.width - 4) * Math.max(0, Math.min(1, bar.value)))
            color: bar.warn ? Kirigami.Theme.negativeTextColor : root.phosphor
            // no width animation: it would redraw the glow layer on every frame
        }
    }
    component Meter: RowLayout {
        property string label
        property real value: 0
        property string readout
        property bool warn: false
        spacing: root.fpx * 0.5
        Layout.fillWidth: true
        T { text: parent.label; Layout.preferredWidth: root.fpx * 3.2 }
        Bar { value: parent.value; warn: parent.warn }
        T { text: parent.readout; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 5.2; elide: Text.ElideNone }
    }
    component Spark: Canvas {
        property var values: []
        Layout.fillWidth: true
        implicitHeight: root.fpx * 2
        onValuesChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = root.phosphor;
            ctx.globalAlpha = 0.35;
            ctx.lineWidth = 1;
            for (var gy = 0; gy <= 2; gy++) {
                var yy = Math.round(gy * (height - 1) / 2) + 0.5;
                ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(width, yy); ctx.stroke();
            }
            ctx.globalAlpha = 1.0;
            ctx.lineWidth = 2;
            ctx.beginPath();
            var n = 60;
            for (var i = 0; i < values.length; i++) {
                var x = width - (values.length - 1 - i) * (width / (n - 1));
                var y = height - 1 - values[i] * (height - 2);
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }
    component Btn: T {
        signal clicked()
        opacity: bma.containsMouse ? 1.0 : 0.7
        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component Sub: RowLayout {
        property string head
        property string detail
        Layout.fillWidth: true
        Layout.topMargin: root.fpx * 0.15
        T { text: parent.head; font.letterSpacing: 2 }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.phosphor; opacity: 0.25 }
        T { text: parent.detail; opacity: 0.6; font.pixelSize: root.fpx * 0.85 }
    }
    component Section: Item {
        id: sec
        property string title
        property bool glow: true
        property bool fillBody: false      // only the terminal stretches its contents; other boxes keep them at the top
        default property alias content: body.data
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + root.fpx * (root.solid ? 1.4 : 1.6)
        Rectangle {
            visible: !root.solid
            anchors.fill: parent
            anchors.topMargin: root.fpx * 0.5
            color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.9)
            border.color: Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, 0.7)
            border.width: 1
        }
        Rectangle {   // solid mode: a divider rule the title sits on
            visible: root.solid
            y: Math.round(root.fpx * 0.5)
            width: parent.width
            height: 1
            color: root.phosphor
            opacity: 0.45
        }
        Rectangle {  // title tab breaks the top border
            x: root.solid ? 0 : root.fpx * 0.8
            width: titleText.implicitWidth + root.fpx
            height: root.fpx
            color: root.bg
            T { id: titleText; anchors.centerIn: parent; text: sec.title; font.letterSpacing: 2 }
        }
        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: sec.fillBody ? parent.bottom : undefined
            anchors.topMargin: root.fpx * 1.2
            anchors.leftMargin: root.solid ? 0 : root.fpx * 0.8
            anchors.rightMargin: root.solid ? 0 : root.fpx * 0.8
            anchors.bottomMargin: root.solid ? root.fpx * 0.2 : root.fpx * 0.5
            spacing: root.fpx * 0.2
            layer.enabled: sec.glow
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.phosphor
                shadowBlur: 0.35
                shadowOpacity: 0.55
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }

    // ---------------------------------------------------------------- unified layout
    readonly property var comps: ({ files: filesC, vitals: vitalsC, profile: profileC, weather: weatherC, clock: clockC, net: netC,
                                    disks: diskC, procs: procC, apps: appC, media: mediaC, notes: notesC })
    // rough heights (in text lines) used to balance the columns
    function est(s) {
        switch (s) {
        case "vitals": return 18;
        case "profile": return 14.5;
        case "files": return 11;
        case "weather": return 10;
        case "clock": return 13;
        case "net": return 7.5;
        case "disks": return 4 + 2 * (sys ? sys.fs.length : 3) + (sys ? sys.io.length : 2);
        case "procs": return 11;
        case "apps": return 14;
        case "media": return 6;
        case "notes": return 9;
        }
        return 6;
    }
    function dropOrder(list) {
        return ["notes", "media", "clock", "procs", "net", "weather", "files", "disks", "profile"].filter(x => list.indexOf(x) >= 0);
    }
    function lastDropped() {
        var src = compact.length ? compact.concat(sections) : sections;
        var o = dropOrder(src);
        return dropCount > 0 && dropCount <= o.length ? o[dropCount - 1] : "";
    }
    property int dropCount: 0        // boxes hidden from the end of the list because the screen is too short
    property real dropAtHeight: 0
    property bool justUndropped: false
    property real undropFailedAt: -1000
    function balance(n) {
        var cols = [], h = [];
        for (var i = 0; i < n; i++) { cols.push([]); h.push(0); }
        // a single narrow column can't hold everything: use the compact set
        var src = n === 1 && compact.length ? compact : sections;
        var list = src.filter(x => comps[x] !== undefined);
        if (dropCount > 0) {
            var gone = dropOrder(list).slice(0, dropCount);
            list = list.filter(x => gone.indexOf(x) < 0);
        }
        if (n > 1 && pinnedCols.length > 1 && n >= pinnedCols.length) {
            var out = [];
            for (var pc = 0; pc < pinnedCols.length; pc++) out.push(pinnedCols[pc].filter(x => list.indexOf(x) >= 0));
            // keep the requested column count: fewer columns than groups never happens here
            return out;
        }
        for (var j = 0; j < list.length; j++) {
            var k = 0;
            for (var c = 1; c < n; c++) if (h[c] < h[k] - 0.5) k = c;
            cols[k].push(list[j]);
            h[k] += est(list[j]) + 1.2;
        }
        return cols;
    }

    fullRepresentation: Item {
        id: full
        Layout.minimumWidth: root.fpx * 18
        Layout.preferredWidth: root.fpx * 60
        Layout.preferredHeight: root.fpx * 50
        Component.onCompleted: root.fetchWeather()

        readonly property int fitCols: Math.max(1, Math.min(6, Math.floor(width / (Plasmoid.configuration.fontSize * 17))))
        readonly property int nCols: Plasmoid.configuration.columns > 0 ? Plasmoid.configuration.columns
                                     : (root.pinnedCols.length > 1 && fitCols >= root.pinnedCols.length ? root.pinnedCols.length : Math.min(fitCols, 2))
        readonly property var colLists: root.balance(nCols)
        readonly property real gap: root.fpx * (root.solid ? 0.35 : 0.6)
        readonly property bool expanded: Plasmoid.configuration.terminal && Plasmoid.configuration.termExpanded
        // compact terminal: fixed height (~7 lines); the boxes above take the rest of the space
        readonly property real termMin: root.fpx * (nCols === 1 ? 7.5 : 9.5)

        function bottomH() { return bottomCol.visible ? bottomCol.implicitHeight + gap : 0; }
        // auto-fit: measure, then scale the font so the columns + terminal fill the widget without scrolling
        function refit() {
            if (expanded) return;
            var need = colsRow.implicitHeight + bottomH() + (termSec.visible ? termMin + gap : 0);
            if (need <= 0 || height <= 0) return;
            var ratio = height / need;
            var minScale = 13 / Plasmoid.configuration.fontSize;          // don't go below ~13 px text
            if (ratio < 1.0) {
                if (root.fitScale > minScale + 0.005) {
                    root.fitScale = Math.max(minScale, root.fitScale * ratio * 0.98);
                } else {
                    if (root.justUndropped) root.undropFailedAt = height;   // that box really doesn't fit: stop trying
                    root.justUndropped = false;
                    root.dropCount++;                                  // still too tall: hide the last box
                    root.dropAtHeight = height;
                }
                refitTimer.restart();
            } else if (root.dropCount > 0 && Math.abs(height - root.undropFailedAt) > root.fpx * 4
                       && (height - need > (root.est(root.lastDropped()) + 1.6) * root.fpx + gap
                           || height > root.dropAtHeight + root.fpx * 4)) {
                root.dropCount--;                                      // room again: bring a box back
                root.justUndropped = true;
                refitTimer.restart();
            } else if (ratio > 1.08 && root.fitScale < 1.0 && root.dropCount === 0) {
                root.fitScale = Math.min(1.0, root.fitScale * Math.min(ratio, 1.1));
                refitTimer.restart();
            }
        }
        Timer { id: refitTimer; interval: 250; onTriggered: full.refit() }
        onHeightChanged: refitTimer.restart()
        onWidthChanged: refitTimer.restart()
        Connections { target: colsRow; function onImplicitHeightChanged() { refitTimer.restart(); } }
        Connections { target: bottomCol; function onImplicitHeightChanged() { refitTimer.restart(); } }

        Rectangle {   // one solid block behind everything
            visible: root.solid
            anchors.fill: parent
            color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.94)
            border.width: 1
            border.color: Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, 0.8)
            Rectangle { x: 3; y: 3; width: parent.width - 6; height: parent.height - 6; color: "transparent"; border.width: 1; border.color: root.phosphor; opacity: 0.25 }
        }
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: root.solid ? root.fpx * 0.8 : 0
            clip: true
            contentWidth: width
            contentHeight: height          // no scrolling, ever: text shrinks / low-priority boxes hide instead
            interactive: false

            ColumnLayout {
                width: flick.width
                height: flick.contentHeight
                spacing: full.gap

                RowLayout {
                    id: colsRow
                    visible: !full.expanded
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignTop
                    spacing: full.gap
                    Repeater {
                        model: full.nCols
                        delegate: ColumnLayout {
                            id: colItem
                            required property int index
                            readonly property var list: full.colLists[index]
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.alignment: Qt.AlignTop
                            spacing: full.gap
                            Repeater {
                                model: colItem.list
                                delegate: Loader {
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    // the last box in each column stretches down to line up with its neighbours
                                    Layout.fillHeight: index === colItem.list.length - 1
                                    sourceComponent: root.comps[modelData] || null
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: bottomCol
                    visible: !full.expanded && root.bottomSections.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: implicitHeight
                    spacing: full.gap
                    Repeater {
                        model: full.expanded ? [] : root.bottomSections
                        delegate: Loader {
                            required property string modelData
                            Layout.fillWidth: true
                            sourceComponent: root.comps[modelData] || null
                        }
                    }
                }

                Section {
                    id: termSec
                    fillBody: true
                    title: full.expanded ? "TERMLINK // FULL" : "TERMLINK"
                    visible: Plasmoid.configuration.terminal
                    Layout.fillWidth: true
                    Layout.fillHeight: full.expanded
                    Layout.minimumHeight: full.termMin
                    Layout.preferredHeight: full.termMin
                    Layout.maximumHeight: full.expanded ? 100000 : full.termMin
                    glow: false
                    Loader {
                        id: termLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        property bool fellBack: Plasmoid.configuration.terminalMode === "builtin"
                        readonly property var term: item
                        source: fellBack ? "TermConsole.qml" : "TermReal.qml"
                        onStatusChanged: if (status === Loader.Error && !fellBack) fellBack = true
                        onLoaded: {
                            item.phosphor = Qt.binding(() => root.phosphor);
                            item.fpx = Qt.binding(() => root.fpx);
                            if (item.bin !== undefined) { item.bin = root.bin; item.bg = Qt.binding(() => root.bg); }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Btn {
                            text: termLoader.fellBack ? "[ CONSOLE ]" : "[ SHELL ]"
                            font.pixelSize: root.fpx * 0.85
                            onClicked: {   // switch engine: real shell <-> built-in console
                                Plasmoid.configuration.terminalMode = termLoader.fellBack ? "auto" : "builtin";
                                termLoader.fellBack = Plasmoid.configuration.terminalMode === "builtin";
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Btn { text: "[ COPY ]"; font.pixelSize: root.fpx * 0.85; onClicked: if (termLoader.item) termLoader.item.copy() }
                        Btn { text: "[ PASTE ]"; font.pixelSize: root.fpx * 0.85; onClicked: if (termLoader.item) termLoader.item.paste() }
                        Btn { text: "[ RESET ]"; font.pixelSize: root.fpx * 0.85; onClicked: if (termLoader.item) termLoader.item.restart() }
                        Btn {
                            text: full.expanded ? "[ SHRINK ]" : "[ EXPAND ]"
                            font.pixelSize: root.fpx * 0.85
                            onClicked: Plasmoid.configuration.termExpanded = !Plasmoid.configuration.termExpanded
                        }
                        Btn { text: "[ KONSOLE ]"; font.pixelSize: root.fpx * 0.85; onClicked: root.sh("setsid konsole >/dev/null 2>&1 &") }

                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- sections
    Component {
        id: weatherC
        Section {
            id: ws
            title: "WEATHER"
            readonly property var cur: root.weather ? root.weather.current : null
            readonly property var daily: root.weather ? root.weather.daily : null
            readonly property string u: (root.cfg.weather && root.cfg.weather.units === "C") ? "C" : "F"
            T { text: ((root.cfg.weather && root.cfg.weather.label) || "").toUpperCase(); opacity: 0.75; Layout.fillWidth: true }
            T { visible: root.weatherErr.length > 0; text: "> " + root.weatherErr }
            RowLayout {
                visible: ws.cur !== null
                spacing: root.fpx
                T { text: ws.cur ? Math.round(ws.cur.temperature_2m) + "°" + ws.u : ""; font.pixelSize: root.fpx * 2.6 }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    T { text: ws.cur ? root.wmo(ws.cur.weather_code) : ""; Layout.fillWidth: true }
                    T {
                        Layout.fillWidth: true
                        opacity: 0.75
                        text: ws.cur ? "FEELS " + Math.round(ws.cur.apparent_temperature) + "°  HUM " + ws.cur.relative_humidity_2m + "%" : ""
                    }
                    T {
                        Layout.fillWidth: true
                        opacity: 0.75
                        text: ws.cur ? "WIND " + Math.round(ws.cur.wind_speed_10m) + (ws.u === "C" ? " KM/H" : " MPH") : ""
                    }
                }
            }
            RowLayout {
                visible: ws.daily !== null
                Layout.fillWidth: true
                Repeater {
                    model: ws.daily ? Math.min(4, ws.daily.time.length) : 0
                    delegate: ColumnLayout {
                        required property int index
                        Layout.fillWidth: true
                        spacing: 0
                        T {
                            Layout.alignment: Qt.AlignHCenter
                            text: index === 0 ? "TODAY" : new Date(ws.daily.time[index] + "T12:00").toLocaleDateString(Qt.locale("en_US"), "ddd").toUpperCase()
                        }
                        T { Layout.alignment: Qt.AlignHCenter; text: root.glyph(ws.daily.weather_code[index]) }
                        T { Layout.alignment: Qt.AlignHCenter; text: Math.round(ws.daily.temperature_2m_max[index]) + "/" + Math.round(ws.daily.temperature_2m_min[index]) }
                        T { Layout.alignment: Qt.AlignHCenter; opacity: 0.7; text: (ws.daily.precipitation_probability_max[index] || 0) + "%" }
                    }
                }
            }
        }
    }
    Component {
        id: filesC
        Section {
            id: fs
            title: "FILES"
            fillBody: true          // grows to fill the rest of its column
            readonly property string home: root.profile && root.profile.home ? root.profile.home : ""
            property string dir: Plasmoid.configuration.filesDir || home
            function go(p) { if (!p) return; Plasmoid.configuration.filesDir = p; fs.dir = p; }
            function short(p) { return fs.home && p.indexOf(fs.home) === 0 ? "~" + p.slice(fs.home.length) : p; }
            FolderListModel {
                id: fm
                folder: fs.dir ? "file://" + fs.dir : ""
                showDirsFirst: true
                showDotAndDotDot: false
                showHidden: false
                sortField: FolderListModel.Name
            }
            RowLayout {
                Layout.fillWidth: true
                Btn { text: "[ ^ ]"; onClicked: { var d = fs.dir.replace(/\/[^\/]+\/?$/, ""); fs.go(d.length ? d : "/"); } }
                T { text: fs.short(fs.dir) + "/"; Layout.fillWidth: true; elide: Text.ElideLeft }
                T { text: fm.count + " ITEMS"; opacity: 0.55; font.pixelSize: root.fpx * 0.85 }
            }
            Flow {
                Layout.fillWidth: true
                spacing: root.fpx * 0.5
                Repeater {
                    model: [["~", ""], ["DOCS", "/Documents"], ["DL", "/Downloads"], ["PICS", "/Pictures"], ["DESK", "/Desktop"]]
                    delegate: Btn {
                        required property var modelData
                        text: "[" + modelData[0] + "]"
                        font.pixelSize: root.fpx * 0.85
                        onClicked: fs.go(fs.home + modelData[1])
                    }
                }
                Btn { text: "[DOLPHIN]"; font.pixelSize: root.fpx * 0.85; onClicked: root.sh("setsid dolphin '" + fs.dir.replace(/'/g, "") + "' >/dev/null 2>&1 &") }
            }
            ListView {
                id: flist
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.fpx * 1.2 * 6
                Layout.preferredHeight: root.fpx * 1.2 * 6
                clip: true
                model: fm
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { }
                delegate: Item {
                    id: row
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    required property var fileSize
                    required property var fileModified
                    width: flist.width
                    height: root.fpx * 1.2
                    Rectangle {
                        anchors.fill: parent
                        color: rma.pressed ? root.phosphor : (rma.containsMouse ? Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, 0.12) : "transparent")
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.rightMargin: root.fpx * 0.6
                        spacing: root.fpx * 0.4
                        Kirigami.Icon {
                            Layout.preferredWidth: root.fpx; Layout.preferredHeight: root.fpx
                            source: row.fileIsDir ? "folder" : "text-x-generic"
                        }
                        T {
                            text: row.fileName + (row.fileIsDir ? "/" : "")
                            Layout.fillWidth: true
                            color: rma.pressed ? root.bg : root.phosphor
                            opacity: row.fileIsDir ? 1 : 0.8
                        }
                        T {
                            visible: !row.fileIsDir
                            text: row.fileSize >= 1073741824 ? (row.fileSize / 1073741824).toFixed(1) + "G"
                                : row.fileSize >= 1048576 ? (row.fileSize / 1048576).toFixed(1) + "M"
                                : row.fileSize >= 1024 ? Math.round(row.fileSize / 1024) + "K" : row.fileSize + "B"
                            opacity: 0.55
                            font.pixelSize: root.fpx * 0.85
                            color: rma.pressed ? root.bg : root.phosphor
                        }
                    }
                    MouseArea {
                        id: rma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.fileIsDir ? fs.go(row.filePath)
                                                 : root.sh("setsid xdg-open '" + row.filePath.replace(/'/g, "'\\''") + "' >/dev/null 2>&1 &")
                    }
                }
            }
        }
    }
    Component {
        id: vitalsC
        Section {
            id: vs
            title: "VITALS"
            readonly property var g: root.sys ? root.sys.gpu : null
            readonly property var m: root.sys ? root.sys.mem : null
            Sub { head: "CPU"; detail: root.sys ? root.sys.cpu.model.replace(/\(R\)|\(TM\)|CPU|Processor|\s+\d+-Core/g, "").replace(/\s+/g, " ").trim().toUpperCase() : "" }
            Meter { label: "LOAD"; value: root.cpuUse; readout: root.pct(root.cpuUse * 100); warn: root.cpuUse > 0.9 }
            Meter {
                property var t: root.sys ? root.sys.cpu.temp : null
                label: "TEMP"; value: t === null ? 0 : t / 100; readout: t === null ? "--" : t + "°C"; warn: t !== null && t >= 85
            }
            Spark { values: root.cpuHist; implicitHeight: root.fpx * 1.5 }

            Sub { head: "GPU"; detail: vs.g ? vs.g.name.toUpperCase() : "NO TELEMETRY" }
            Meter { visible: vs.g !== null; label: "LOAD"; value: vs.g ? vs.g.util / 100 : 0; readout: vs.g ? root.pct(vs.g.util) : "--" }
            Meter {
                visible: vs.g !== null
                label: "TEMP"; value: vs.g && vs.g.temp !== null ? vs.g.temp / 100 : 0
                readout: vs.g && vs.g.temp !== null ? vs.g.temp + "°C" : "--"; warn: !!(vs.g && vs.g.temp >= 83)
            }
            Meter {
                visible: !!(vs.g && vs.g.memTotal !== null)
                label: "VRAM"; value: vs.g && vs.g.memTotal ? vs.g.memUsed / vs.g.memTotal : 0
                readout: vs.g && vs.g.memTotal ? (vs.g.memUsed / 1024).toFixed(1) + "/" + Math.round(vs.g.memTotal / 1024) + "G" : "--"
            }
            RowLayout {
                visible: vs.g !== null
                Layout.fillWidth: true
                T { text: vs.g && vs.g.power !== null ? "POWER " + Math.round(vs.g.power) + " W" : ""; opacity: 0.75; Layout.fillWidth: true }
                T { text: vs.g && vs.g.fan !== null ? "FAN " + vs.g.fan + "%" : ""; opacity: 0.75 }
            }
            Spark { visible: vs.g !== null; values: root.gpuHist; implicitHeight: root.fpx * 1.5 }

            Sub { head: "MEMORY"; detail: vs.m ? Math.round(vs.m.total / 1048576) + " GB" : "" }
            Meter {
                label: "RAM"; value: vs.m ? 1 - vs.m.avail / vs.m.total : 0
                readout: vs.m ? root.gb((vs.m.total - vs.m.avail) * 1024) + "/" + Math.round(vs.m.total / 1048576) + "G" : "--"
                warn: !!(vs.m && vs.m.avail / vs.m.total < 0.1)
            }
            Meter {
                visible: !!(vs.m && vs.m.swapTotal > 0)
                label: "SWAP"; value: vs.m && vs.m.swapTotal ? 1 - vs.m.swapFree / vs.m.swapTotal : 0
                readout: vs.m ? root.gb((vs.m.swapTotal - vs.m.swapFree) * 1024) + "/" + Math.round(vs.m.swapTotal / 1048576) + "G" : "--"
            }
        }
    }
    Component {
        id: diskC
        Section {
            title: "STORAGE"
            Repeater {
                model: root.sys ? root.sys.fs : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        T { text: modelData.mount; Layout.fillWidth: true }
                        T { text: root.gb(modelData.used) + " / " + root.gb(modelData.size) + " GB"; opacity: 0.75 }
                    }
                    Bar { value: modelData.used / modelData.size; warn: modelData.used / modelData.size > 0.9 }
                }
            }
            T { text: "ACTIVITY"; opacity: 0.6; Layout.topMargin: root.fpx * 0.3 }
            Repeater {
                model: root.ioRates
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    T { text: modelData.name; Layout.preferredWidth: root.fpx * 4.6; elide: Text.ElideNone }
                    T { text: "R " + root.rate(modelData.rd); Layout.fillWidth: true }
                    T { text: "W " + root.rate(modelData.wr); Layout.fillWidth: true }
                    T { text: Math.round(modelData.busy) + "%"; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 2.6; elide: Text.ElideNone }
                }
            }
        }
    }
    Component {
        id: procC
        Section {
            title: "PROCESSES"
            RowLayout {
                Layout.fillWidth: true
                opacity: 0.6
                T { text: "NAME"; Layout.fillWidth: true }
                T { text: "CPU"; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 3 }
                T { text: "MEM"; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 3 }
            }
            Repeater {
                model: root.procs.slice(0, 8)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    T { text: modelData.cmd; Layout.fillWidth: true }
                    T { text: modelData.cpu.toFixed(1); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 3 }
                    T { text: modelData.mem.toFixed(1); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 3 }
                }
            }
        }
    }
    Component {
        id: appC
        Section {
            id: appSec
            title: "PROGRAMS"
            readonly property var groupKeys: ["PINNED", "ALL", "REMOTE", "AI", "GAMES", "WEB", "MEDIA", "GFX", "OFFICE", "DEV", "SYS", "UTIL", "OTHER"]
            readonly property var counts: {
                var c = { ALL: root.allApps.length, PINNED: 0 };
                for (var i = 0; i < root.allApps.length; i++) {
                    var a = root.allApps[i];
                    c[a.group] = (c[a.group] || 0) + 1;
                    if (root.pinnedIds.indexOf(a.id) >= 0) c.PINNED++;
                }
                return c;
            }
            readonly property var tabs: groupKeys.filter(k => k === "ALL" || (counts[k] || 0) > 0)
            readonly property string cat: tabs.indexOf(Plasmoid.configuration.appCategory) >= 0 ? Plasmoid.configuration.appCategory : "ALL"
            readonly property var shown: {
                var q = root.appQuery.toLowerCase();
                return root.allApps.filter(function (a) {
                    if (q.length) return (a.name + " " + a.generic + " " + a.id).toLowerCase().indexOf(q) >= 0;
                    if (cat === "ALL") return true;
                    if (cat === "PINNED") return root.pinnedIds.indexOf(a.id) >= 0;
                    return a.group === cat;
                });
            }
            readonly property int cols: Math.max(3, Math.floor(width / (root.fpx * 4.4)))
            // never show an empty row: use fewer rows when the tab has fewer apps
            readonly property int rows: Math.max(1, Math.min(Plasmoid.configuration.appRows, Math.ceil(shown.length / cols)))
            readonly property int perPage: cols * rows
            readonly property int pages: Math.max(1, Math.ceil(shown.length / perPage))
            readonly property int page: Math.min(root.appPage, pages - 1)
            function setCat(k) { root.appQuery = ""; root.appPage = 0; Plasmoid.configuration.appCategory = k; }

            RowLayout {
                Layout.fillWidth: true
                T { text: "FIND >"; opacity: 0.7 }
                TextInput {
                    id: find
                    Layout.fillWidth: true
                    text: root.appQuery
                    color: root.phosphor
                    selectionColor: root.phosphor
                    selectedTextColor: root.bg
                    font.family: "VT323"
                    font.pixelSize: root.fpx
                    onTextEdited: { root.appQuery = text; root.appPage = 0; }
                    Keys.onEscapePressed: { text = ""; root.appQuery = ""; }
                    Keys.onReturnPressed: if (appSec.shown.length) root.launch(appSec.shown[appSec.page * appSec.perPage].file)
                    T { visible: !find.text && !find.activeFocus; text: "_"; opacity: 0.5 }
                }
                T { text: appSec.shown.length + "/" + root.allApps.length; opacity: 0.6 }
            }
            Flow {
                Layout.fillWidth: true
                spacing: root.fpx * 0.25
                Repeater {
                    model: appSec.tabs
                    delegate: Item {
                        id: ct
                        required property string modelData
                        readonly property bool on: appSec.cat === modelData && !root.appQuery.length
                        width: ctt.implicitWidth + root.fpx * 0.6
                        height: root.fpx * 1.15
                        Rectangle {
                            anchors.fill: parent
                            color: ct.on ? root.phosphor : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, ct.on || cm.containsMouse ? 1 : 0.3)
                        }
                        T { id: ctt; anchors.centerIn: parent; text: ct.modelData; font.pixelSize: root.fpx * 0.8; color: ct.on ? root.bg : root.phosphor }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appSec.setCat(ct.modelData) }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: appSec.cols
                columnSpacing: 0
                rowSpacing: 0
                WheelHandler {
                    onWheel: (ev) => root.appPage = Math.max(0, Math.min(appSec.pages - 1, appSec.page + (ev.angleDelta.y < 0 ? 1 : -1)))
                }
                Repeater {
                    model: appSec.shown.slice(appSec.page * appSec.perPage, (appSec.page + 1) * appSec.perPage)
                    delegate: Item {
                        id: tile
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: root.fpx * 3.4
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            color: ma.pressed ? root.phosphor : (ma.containsMouse ? Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, 0.12) : "transparent")
                            border.color: root.phosphor
                            border.width: ma.containsMouse ? 1 : 0
                        }
                        Kirigami.Icon {
                            id: ic
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.fpx * 0.3
                            width: Math.round(root.fpx * 1.7); height: width
                            source: tile.modelData.icon || "application-x-executable"
                            opacity: ma.pressed ? 0.6 : 1.0
                        }
                        T {
                            anchors.top: ic.bottom
                            anchors.topMargin: 1
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 2
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name.toUpperCase()
                            font.pixelSize: root.fpx * 0.72
                            color: ma.pressed ? root.bg : root.phosphor
                        }
                        PlasmaCore.ToolTipArea {
                            anchors.fill: parent
                            mainText: tile.modelData.name
                            subText: tile.modelData.generic || tile.modelData.group
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launch(tile.modelData.file)
                            }
                        }
                    }
                }
                Repeater {   // keep the block the same height on short pages
                    model: Math.max(0, appSec.perPage - Math.min(appSec.perPage, appSec.shown.length - appSec.page * appSec.perPage))
                    delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: root.fpx * 3.4 }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                T { text: root.appQuery.length ? "FILTER " + root.appQuery.toUpperCase() : appSec.cat; opacity: 0.55; Layout.fillWidth: true; font.pixelSize: root.fpx * 0.85 }
                Btn { text: "[ < ]"; opacity: appSec.page > 0 ? 1 : 0.3; onClicked: root.appPage = Math.max(0, appSec.page - 1) }
                T { text: (appSec.page + 1) + "/" + appSec.pages; font.pixelSize: root.fpx * 0.85 }
                Btn { text: "[ > ]"; opacity: appSec.page < appSec.pages - 1 ? 1 : 0.3; onClicked: root.appPage = Math.min(appSec.pages - 1, appSec.page + 1) }
            }
        }
    }

    Component {
        id: clockC
        Section {
            id: cs
            title: "CHRONO"
            readonly property date n: root.now
            readonly property bool h24: !!(root.cfg.clock && root.cfg.clock.h24)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.fpx * 0.3
                T {
                    text: cs.h24 ? Qt.formatTime(cs.n, "HH:mm:ss") : Qt.formatTime(cs.n, "h:mm:ss AP").replace(/\s*[AP]M$/i, "")   // "h" is only 12-hour when AP is in the same format
                    font.pixelSize: root.fpx * 3.4
                }
                T {
                    visible: !cs.h24
                    Layout.alignment: Qt.AlignBottom
                    text: Qt.formatTime(cs.n, "AP").toUpperCase()
                    font.pixelSize: root.fpx * 1.3
                    opacity: 0.8
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.fpx * 0.6
                Btn {
                    text: cs.h24 ? "  12H  " : "[ 12H ]"
                    font.pixelSize: root.fpx * 0.85
                    opacity: cs.h24 ? 0.45 : 1.0
                    onClicked: root.sh("\"$HOME/.local/bin/poseidonos-clock\" 12")
                }
                Btn {
                    text: cs.h24 ? "[ 24H ]" : "  24H  "
                    font.pixelSize: root.fpx * 0.85
                    opacity: cs.h24 ? 1.0 : 0.45
                    onClicked: root.sh("\"$HOME/.local/bin/poseidonos-clock\" 24")
                }
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: cs.n.toLocaleDateString(Qt.locale("en_US"), "dddd  yyyy.MM.dd").toUpperCase()
                opacity: 0.8
            }
            GridLayout {
                id: cal
                Layout.fillWidth: true
                Layout.topMargin: root.fpx * 0.3
                columns: 7
                rowSpacing: 0
                columnSpacing: 0
                readonly property int y0: cs.n.getFullYear()
                readonly property int m0: cs.n.getMonth()
                readonly property int lead: new Date(y0, m0, 1).getDay()
                readonly property int days: new Date(y0, m0 + 1, 0).getDate()
                Repeater {
                    model: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
                    delegate: T { required property string modelData; text: modelData; opacity: 0.55; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                }
                Repeater {
                    model: 42
                    delegate: Item {
                        required property int index
                        readonly property int day: index - cal.lead + 1
                        readonly property bool valid: day >= 1 && day <= cal.days
                        readonly property bool today: day === cs.n.getDate()
                        visible: index < Math.ceil((cal.lead + cal.days) / 7) * 7
                        Layout.fillWidth: true
                        implicitHeight: root.fpx * 1.15
                        Rectangle { anchors.fill: parent; anchors.margins: 1; color: root.phosphor; visible: parent.valid && parent.today }
                        T {
                            anchors.centerIn: parent
                            text: parent.valid ? parent.day : ""
                            color: parent.today ? root.bg : root.phosphor
                            opacity: parent.today ? 1 : 0.8
                        }
                    }
                }
            }
        }
    }
    Component {
        id: netC
        Section {
            id: ns
            title: "NETWORK"
            readonly property var n: root.sys ? root.sys.net : null
            RowLayout {
                Layout.fillWidth: true
                T { text: ns.n && ns.n.if ? ns.n.if : "OFFLINE"; Layout.fillWidth: true }
                T { text: ns.n && ns.n.ip ? ns.n.ip : ""; opacity: 0.75 }
            }
            RowLayout {
                Layout.fillWidth: true
                T { text: "DOWN"; Layout.preferredWidth: root.fpx * 3.2; elide: Text.ElideNone }
                T { text: root.rate(root.netRate.rx); Layout.fillWidth: true }
                T { text: "UP"; Layout.preferredWidth: root.fpx * 2; elide: Text.ElideNone }
                T { text: root.rate(root.netRate.tx); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 5.2; elide: Text.ElideNone }
            }
            Spark {
                readonly property real peak: Math.max(131072, Math.max.apply(null, root.netHist.length ? root.netHist : [0]))
                values: root.netHist.map(v => v / peak)
            }
            T {
                text: "LATENCY " + (root.info && root.info.ping !== null ? Math.round(root.info.ping) + " MS" : "--") + "   (1.1.1.1)"
                opacity: 0.75
            }
        }
    }
    Component {
        id: mediaC
        Section {
            id: ms
            title: "RADIO"
            readonly property var m: root.media
            readonly property bool ok: !!(m && !m.missing && !m.none)
            T { visible: !!(ms.m && ms.m.missing); text: "> INSTALL 'playerctl' FOR NOW-PLAYING"; opacity: 0.7 }
            T { visible: !!(ms.m && ms.m.none); text: "> NO SIGNAL"; opacity: 0.7 }
            T { visible: ms.ok; text: ms.ok ? (ms.m.title || "UNKNOWN").toUpperCase() : ""; Layout.fillWidth: true }
            T { visible: ms.ok; text: ms.ok ? ((ms.m.artist || "") + "  //  " + ms.m.player).toUpperCase() : ""; opacity: 0.7; Layout.fillWidth: true }
            Bar { visible: ms.ok && ms.m.len > 0; value: ms.ok && ms.m.len > 0 ? ms.m.pos / ms.m.len : 0 }
            RowLayout {
                visible: ms.ok
                Layout.alignment: Qt.AlignHCenter
                spacing: root.fpx * 1.2
                Btn { text: "[ |<< ]"; onClicked: root.sh(root.bin + " media-ctl previous") }
                Btn { text: ms.ok && ms.m.status === "Playing" ? "[ || ]" : "[ > ]"; onClicked: root.sh(root.bin + " media-ctl play-pause") }
                Btn { text: "[ >>| ]"; onClicked: root.sh(root.bin + " media-ctl next") }
            }
        }
    }
    Component {
        id: notesC
        Section {
            title: "MEMO"
            QQC2.TextArea {
                id: memo
                Layout.fillWidth: true
                Layout.preferredHeight: root.fpx * 7
                text: root.notes
                placeholderText: "> type notes here, saved automatically"
                placeholderTextColor: Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, 0.4)
                wrapMode: TextEdit.Wrap
                color: root.phosphor
                selectionColor: root.phosphor
                selectedTextColor: root.bg
                font.family: "VT323"
                font.pixelSize: root.fpx
                background: Rectangle { color: "transparent"; border.width: memo.activeFocus ? 1 : 0; border.color: root.phosphor; opacity: 0.5 }
                onTextChanged: if (root.notesLoaded && text !== root.notes) { root.notes = text; notesSave.restart(); }
            }
        }
    }

    component Toggle: Rectangle {
        id: tg
        property string label
        property string glyph
        property bool on: false
        property bool dim: false          // busy: greyed out and not clickable
        signal clicked()
        signal rightClicked()
        Layout.fillWidth: true
        opacity: dim ? 0.45 : 1
        implicitHeight: root.fpx * 3.3
        color: tma.pressed ? root.phosphor : (on ? Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, 0.18) : "transparent")
        border.width: 1
        border.color: Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, on || tma.containsMouse ? 0.95 : 0.4)
        Column {
            anchors.centerIn: parent
            width: parent.width - 6
            T { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: tg.glyph; font.pixelSize: root.fpx * 1.2; color: tma.pressed ? root.bg : root.phosphor }
            T { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: tg.label; font.pixelSize: root.fpx * 0.8; color: tma.pressed ? root.bg : root.phosphor; opacity: tg.on ? 1 : 0.7 }
        }
        MouseArea {
            id: tma
            anchors.fill: parent
            enabled: !tg.dim
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (m) => m.button === Qt.RightButton ? tg.rightClicked() : tg.clicked()
        }
    }
    Component {
        id: profileC
        Section {
            id: ps
            title: "PROFILE"
            readonly property var p: root.profile
            RowLayout {
                Layout.fillWidth: true
                spacing: root.fpx * 0.6
                Item {   // avatar, recoloured to phosphor with scanlines
                    implicitWidth: root.fpx * 3.4
                    implicitHeight: root.fpx * 3.4
                    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: root.phosphor }
                    Image {
                        id: face
                        anchors.fill: parent
                        anchors.margins: 2
                        source: ps.p && ps.p.face ? "file://" + ps.p.face : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        cache: false
                        layer.enabled: true
                        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: root.phosphor; contrast: 0.2 }
                    }
                    T { anchors.centerIn: parent; visible: !face.visible; text: ps.p ? ps.p.user.charAt(0).toUpperCase() : "?"; font.pixelSize: root.fpx * 2.2 }
                    Column {
                        anchors.fill: parent; anchors.margins: 2; clip: true
                        Repeater { model: Math.ceil(root.fpx * 3.4 / 3); Rectangle { width: parent.width; height: 3; color: "transparent"; Rectangle { width: parent.width; height: 1; color: "black"; opacity: 0.35 } } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ctl("profile") }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    T { text: "WELCOME, " + (ps.p ? (ps.p.name || ps.p.user) : "OPERATOR").toUpperCase(); font.pixelSize: root.fpx * 1.2; Layout.fillWidth: true; fontSizeMode: Text.HorizontalFit; minimumPixelSize: root.fpx * 0.8 }
                    T { text: ps.p ? ps.p.user + "@" + ps.p.host : ""; opacity: 0.7; Layout.fillWidth: true }
                    T {
                        opacity: 0.55
                        Layout.fillWidth: true
                        text: {
                            var h = root.now.getHours();
                            return (h < 5 ? "LATE SHIFT" : h < 12 ? "MORNING SHIFT" : h < 18 ? "DAY SHIFT" : "EVENING SHIFT") + "  //  "
                                   + (root.info ? root.info.shell.toUpperCase() : "");
                        }
                    }
                }
                ColumnLayout {
                    spacing: root.fpx * 0.25
                    Btn { text: "[ LOCK ]"; onClicked: root.ctl("lock") }
                    Btn { text: "[ POWER ]"; onClicked: root.ctl("power") }
                }
            }
            // ---- system facts
            Sub { head: "SYSTEM"; detail: root.info ? root.info.os.toUpperCase() : "" }
            GridLayout {
                id: sysg
                Layout.fillWidth: true
                columns: 4
                columnSpacing: root.fpx * 0.6
                rowSpacing: 0
                readonly property var i: root.info
                function up(sec) {
                    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
                    return d ? d + "D" + h + "H" : h + "H" + m + "M";
                }
                T { text: "KERNEL"; opacity: 0.55 }   T { text: sysg.i ? sysg.i.kernel.split("-")[0] : "--"; Layout.fillWidth: true }
                T { text: "PLASMA"; opacity: 0.55 }   T { text: sysg.i ? sysg.i.plasma : "--"; Layout.fillWidth: true }
                T { text: "UPTIME"; opacity: 0.55 }   T { text: root.sys ? sysg.up(root.sys.uptime) : "--"; Layout.fillWidth: true }
                T { text: "LOAD"; opacity: 0.55 }     T { text: root.sys ? root.sys.load.split(" ")[0] : "--"; Layout.fillWidth: true }
                T { text: "PKGS"; opacity: 0.55 }     T { text: sysg.i && sysg.i.pkgs !== null ? sysg.i.pkgs : "--"; Layout.fillWidth: true }
                T { text: "UPDATES"; opacity: 0.55 }
                Btn {
                    Layout.fillWidth: true
                    text: sysg.i && sysg.i.updates !== null ? (sysg.i.updates > 0 ? "[" + sysg.i.updates + " NEW]" : "NONE") : "--"
                    color: sysg.i && sysg.i.updates > 0 ? Kirigami.Theme.neutralTextColor : root.phosphor
                    onClicked: if (sysg.i && sysg.i.updates > 0) root.sh("setsid konsole --hold -e sudo pacman -Syu >/dev/null 2>&1 &")
                }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: root.fpx * 0.3
                columns: 3
                columnSpacing: root.fpx * 0.4
                rowSpacing: root.fpx * 0.4
                Toggle {
                    glyph: "<=>"
                    label: ps.p && ps.p.net ? ps.p.net.toUpperCase() : "OFFLINE"
                    on: !!(ps.p && ps.p.net)
                    onClicked: root.ctl("network")
                }
                Toggle {
                    glyph: "(B)"
                    label: ps.p && ps.p.bt !== null ? (ps.p.bt ? "BLUETOOTH ON" : "BLUETOOTH OFF") : "NO BLUETOOTH"
                    on: !!(ps.p && ps.p.bt)
                    onClicked: root.ctl("bt")
                    onRightClicked: root.ctl("bluetooth-settings")
                }
                Toggle { glyph: "(*)"; label: "NIGHT LIGHT"; onClicked: root.ctl("nightlight") }
                Toggle {
                    glyph: "[#]"
                    label: ps.p && ps.p.variant ? ps.p.variant.toUpperCase() : "GREEN"
                    on: true
                    dim: root.switching
                    onClicked: root.ctl("phosphor")
                }
                Toggle { glyph: "=|="; label: "CRT " + (ps.p && ps.p.crt ? "ON" : "OFF"); on: !!(ps.p && ps.p.crt); dim: root.switching; onClicked: root.ctl("crt") }
                Toggle { glyph: "[?]"; label: "SETTINGS"; onClicked: root.sh("setsid systemsettings >/dev/null 2>&1 &") }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: root.fpx * 0.3
                visible: !!(ps.p && ps.p.vol !== null)
                Btn { text: ps.p && ps.p.muted ? "MUTED" : "VOL"; Layout.preferredWidth: root.fpx * 3.2; onClicked: root.ctl("mute") }
                Item {
                    id: volBar
                    Layout.fillWidth: true
                    implicitHeight: root.fpx * 0.8
                    property real v: ps.p && ps.p.vol !== null ? Math.min(1, ps.p.vol / 100) : 0
                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.phosphor; border.width: 1 }
                    Rectangle { x: 2; y: 2; height: parent.height - 4; width: Math.max(0, (parent.width - 4) * volBar.v); color: root.phosphor; opacity: ps.p && ps.p.muted ? 0.35 : 1 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setAt(x) { var n = Math.round(Math.max(0, Math.min(1, x / width)) * 100); volBar.v = n / 100; root.ctl("vol", n); }
                        onPressed: (m) => setAt(m.x)
                        onPositionChanged: (m) => { if (pressed) setAt(m.x); }
                    }
                    WheelHandler { onWheel: (ev) => root.ctl("vol", Math.round(Math.max(0, Math.min(100, volBar.v * 100 + (ev.angleDelta.y > 0 ? 5 : -5))))) }
                }
                T { text: ps.p && ps.p.vol !== null ? ps.p.vol + "%" : ""; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.fpx * 2.6; elide: Text.ElideNone }
            }
        }
    }
}
