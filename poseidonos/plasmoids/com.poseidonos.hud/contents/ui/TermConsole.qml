// Built-in TERMLINK console: runs one command at a time through bash (non-interactive,
// 30 s limit). Keeps its working directory and history. `konsole` opens a real terminal here.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasma5support as P5Support

Item {
    id: con
    property color phosphor: "#1aff80"
    property color bg: "#030a05"
    property int fpx: 18
    property string bin: ""
    property string cwd: ""
    property string home: ""
    property bool busy: false
    property var history: []
    property int hIdx: -1

    function b64(str) {   // UTF-8 safe base64 (b64(string) is deprecated)
        var u = unescape(encodeURIComponent(str)), a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", o = "";
        for (var i = 0; i < u.length; i += 3) {
            var c1 = u.charCodeAt(i), c2 = u.charCodeAt(i + 1), c3 = u.charCodeAt(i + 2);
            var n = (c1 << 16) | ((c2 || 0) << 8) | (c3 || 0);
            o += a[(n >> 18) & 63] + a[(n >> 12) & 63] + (i + 1 < u.length ? a[(n >> 6) & 63] : "=") + (i + 2 < u.length ? a[n & 63] : "=");
        }
        return o;
    }
    function focusInput() { input.forceActiveFocus(); }
    function shortCwd() { return home && cwd.indexOf(home) === 0 ? "~" + cwd.slice(home.length) : (cwd || "~"); }

    property string buffer: ""
    function add(text, kind) {
        var t = text.replace(/\s+$/, "").replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");
        var b = buffer.length ? buffer + "\n" + t : t;
        var ls = b.split("\n");
        if (ls.length > 400) b = ls.slice(-400).join("\n");
        buffer = b;
    }
    function clearAll() { buffer = ""; }
    readonly property bool real: false
    function copy() { if (out.selectedText.length) out.copy(); else { out.selectAll(); out.copy(); out.deselect(); } }
    function paste() { input.paste(); input.forceActiveFocus(); }
    function restart() { clearAll(); add("POSEIDON OS TERMLINK PROTOCOL // type 'help'", "sys"); }

    P5Support.DataSource {
        id: ex
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source.indexOf("#launch-konsole") >= 0) return;
            var out = data.stdout, rc = 0;
            var m = out.match(/\n?__PNCWD__(.*)\n__PNRC__(\d+)\s*$/);
            if (m) { con.cwd = m[1]; rc = Number(m[2]); out = out.slice(0, m.index); }
            if (!con.home) con.home = con.cwd;
            if (source.indexOf(" #init") < 0) {
                if (out.replace(/\s/g, "").length) con.add(out, rc === 0 ? "out" : "err");
                if (data.stderr && data.stderr.length) con.add(data.stderr, "err");
            }
            con.busy = false;
        }
    }
    function exec(cmd, tag) {
        busy = true;
        ex.connectSource(bin + " exec '" + b64(cwd) + "' '" + b64(cmd) + "' #" + (tag || Date.now()));
    }
    function submit(cmd) {
        add(shortCwd() + " > " + cmd, "cmd");
        if (cmd.trim().length) { history.push(cmd); if (history.length > 200) history.shift(); }
        hIdx = -1;
        var c = cmd.trim();
        if (c === "") return;
        if (c === "clear" || c === "cls") { clearAll(); return; }
        if (c === "help") {
            add("TERMLINK built-in console. Commands run in bash, one at a time (30 s limit, no interactive programs).\n"
              + "  clear      clear the screen\n  konsole    open a full Konsole window in the current directory\n"
              + "  Up/Down    history      Ctrl+L  clear\n"
              + "Install the 'qmltermwidget' package for a real interactive shell here.", "sys");
            return;
        }
        if (c === "konsole" || c === "term") {
            ex.connectSource("setsid konsole --workdir '" + (cwd || "$HOME").replace(/'/g, "") + "' >/dev/null 2>&1 & #launch-konsole" + Date.now());
            add("> opening Konsole", "sys");
            return;
        }
        exec(c);
    }
    Component.onCompleted: Qt.callLater(function () {   // after the HUD has passed in bin/colours
        add("POSEIDON OS TERMLINK PROTOCOL // type 'help'", "sys");
        exec("true", "init");
    })

    // output: selectable plain text, always showing the newest lines (no scrollbar)
    Item {
        id: outBox
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: inputRow.top
        anchors.bottomMargin: 4
        clip: true
        TextEdit {
            id: out
            width: parent.width
            y: Math.min(0, parent.height - height)          // pinned to the bottom
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
            color: con.phosphor
            selectionColor: con.phosphor
            selectedTextColor: con.bg
            font.family: "VT323"
            font.pixelSize: con.fpx
            text: con.buffer
            Keys.onPressed: (e) => {
                if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) { out.copy(); e.accepted = true; }
            }
        }
    }
    Row {
        id: inputRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: con.fpx * 1.3
        spacing: con.fpx * 0.4
        Text {
            id: prompt
            anchors.verticalCenter: parent.verticalCenter
            text: con.shortCwd() + (con.busy ? " ..." : " >")
            color: con.phosphor
            font.family: "VT323"
            font.pixelSize: con.fpx
        }
        TextInput {
            id: input
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - prompt.width - parent.spacing
            color: con.phosphor
            selectionColor: con.phosphor
            selectedTextColor: con.bg
            font.family: "VT323"
            font.pixelSize: con.fpx
            enabled: !con.busy
            cursorDelegate: Rectangle {
                width: con.fpx * 0.55
                color: con.phosphor
                SequentialAnimation on opacity { loops: Animation.Infinite; running: input.activeFocus
                    NumberAnimation { to: 0; duration: 450 } NumberAnimation { to: 1; duration: 450 } }
            }
            onAccepted: { var c = text; text = ""; con.submit(c); }
            Keys.onUpPressed: {
                if (!con.history.length) return;
                con.hIdx = con.hIdx < 0 ? con.history.length - 1 : Math.max(0, con.hIdx - 1);
                text = con.history[con.hIdx];
            }
            Keys.onDownPressed: {
                if (con.hIdx < 0) return;
                con.hIdx++;
                if (con.hIdx >= con.history.length) { con.hIdx = -1; text = ""; } else text = con.history[con.hIdx];
            }
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_L && (e.modifiers & Qt.ControlModifier)) { con.clearAll(); e.accepted = true; }
                else if (e.key === Qt.Key_V && (e.modifiers & Qt.ControlModifier)) { input.paste(); e.accepted = true; }
            }
        }
    }
    TapHandler { gesturePolicy: TapHandler.DragThreshold; onTapped: if (!out.selectedText.length) input.forceActiveFocus() }
}
