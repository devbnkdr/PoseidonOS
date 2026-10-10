import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: "PoseidonOS settings"
    toolTipSubText: "Phosphor, CRT, wallpaper, weather"

    readonly property color phosphor: Kirigami.Theme.textColor
    readonly property string bin: "\"$HOME/.local/bin/"
    readonly property string conf: "\"$HOME/.config/poseidonos/"

    // ------------------------------------------------------------ state
    property string variant: "green"
    property var crt: ({ running: false, scanlines: 0.14, vignette: 0.55, roll: 1, flicker: 1 })
    property var desk: ({})
    property bool loaded: false
    property string status: ""
    property bool switching: false

    // phosphor switch is detached and takes a second or two to land
    Timer { id: switchGuard; interval: 1500; onTriggered: { root.switching = false; root.reload(); } }
    // give poseidonos-crt time to start/stop, then confirm what really happened
    Timer { id: crtGuard; interval: 2000; onTriggered: root.reload() }

    function wp(key, def) { var w = desk.wallpaper || {}; return w[key] === undefined ? def : w[key]; }
    function h24() { return !!(desk.clock && desk.clock.h24); }
    function setClock(on) {
        var d = JSON.parse(JSON.stringify(desk)); d.clock = { h24: on }; desk = d;
        run(bin + "poseidonos-clock\" " + (on ? "24" : "12"));   // saves desktop.json + applies to the taskbar clock
    }
    function we(key, def) { var w = desk.weather || {}; return w[key] === undefined ? def : w[key]; }

    P5Support.DataSource {
        id: sh
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source.indexOf(" settings") >= 0) {
                try {
                    var o = JSON.parse(data.stdout);
                    root.variant = o.variant; root.crt = o.crt; root.desk = o.desktop || {};
                    root.loaded = true;
                } catch (e) { root.status = "READ ERROR"; }
            }
        }
    }
    function run(cmd) { sh.connectSource(cmd + " #" + Date.now()); }
    function reload() { run(bin + "poseidonos-stats\" settings"); }
    onExpandedChanged: if (root.expanded) root.reload()
    Component.onCompleted: reload()

    function b64(str) {   // UTF-8 safe base64 (b64(string) is deprecated)
        var u = unescape(encodeURIComponent(str)), a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", o = "";
        for (var i = 0; i < u.length; i += 3) {
            var c1 = u.charCodeAt(i), c2 = u.charCodeAt(i + 1), c3 = u.charCodeAt(i + 2);
            var n = (c1 << 16) | ((c2 || 0) << 8) | (c3 || 0);
            o += a[(n >> 18) & 63] + a[(n >> 12) & 63] + (i + 1 < u.length ? a[(n >> 6) & 63] : "=") + (i + 2 < u.length ? a[n & 63] : "=");
        }
        return o;
    }
    function writeFile(name, text) {
        run("mkdir -p \"$HOME/.config/poseidonos\" && echo " + b64(text) + " | base64 -d > " + conf + name + ".tmp\" && mv " + conf + name + ".tmp\" " + conf + name + "\"");
    }
    function setDesk(section, key, value) {
        var d = JSON.parse(JSON.stringify(desk));
        if (!d[section]) d[section] = {};
        d[section][key] = value;
        desk = d;
        deskTimer.restart();
    }
    Timer { id: deskTimer; interval: 350; onTriggered: root.writeFile("desktop.json", JSON.stringify(root.desk, null, 1)) }

    function setCrt(key, value) {
        var c = JSON.parse(JSON.stringify(crt)); c[key] = value; crt = c;
        crtTimer.restart();
    }
    Timer {
        id: crtTimer; interval: 400
        onTriggered: {
            var c = root.crt;
            root.writeFile("crt.conf", "SCANLINES=" + c.scanlines.toFixed(2) + "\nVIGNETTE=" + c.vignette.toFixed(2)
                           + "\nROLL=" + (c.roll ? 1 : 0) + "\nFLICKER=" + (c.flicker ? 1 : 0) + "\n");
            if (c.running) root.run("sleep 0.3; " + root.bin + "poseidonos-crt\" restart");
        }
    }

    // weather location lookup: US ZIP via zippopotam.us, anything else via open-meteo geocoding
    function lookupLocation(q) {
        q = q.trim();
        if (!q.length) return;
        status = "LOCATING " + q.toUpperCase() + " ...";
        var zip = /^\d{5}$/.test(q);
        var url = zip ? "https://api.zippopotam.us/us/" + q
                      : "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&name=" + encodeURIComponent(q);
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            try {
                var o = JSON.parse(x.responseText), w = JSON.parse(JSON.stringify(root.desk.weather || {}));
                if (zip) {
                    var p = o.places[0];
                    w.lat = Number(p.latitude); w.lon = Number(p.longitude);
                    w.label = p["place name"] + ", " + p["state abbreviation"];
                } else {
                    var r = o.results[0];
                    w.lat = r.latitude; w.lon = r.longitude;
                    w.label = r.name + (r.admin1 ? ", " + r.admin1 : "") + (r.country_code && r.country_code !== "US" ? ", " + r.country_code : "");
                }
                w.location = q;
                var d = JSON.parse(JSON.stringify(root.desk)); d.weather = w; root.desk = d;
                root.writeFile("desktop.json", JSON.stringify(d, null, 1));
                root.status = "LOCATION SET: " + w.label.toUpperCase();
            } catch (e) { root.status = "LOCATION NOT FOUND"; }
        };
        x.open("GET", url);
        x.send();
    }

    // ------------------------------------------------------------ panel button
    compactRepresentation: MouseArea {
        id: btn
        Layout.minimumWidth: label.implicitWidth + height * 0.6
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        // same sizing as the tabs, so [ CFG ] matches them in the taller taskbar
        readonly property real fontPx: Math.max(14, Math.round(Math.min(height, Kirigami.Units.gridUnit * 2) * 0.62))
        readonly property bool atBottom: Plasmoid.location === PlasmaCore.Types.BottomEdge
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: btn.atBottom ? 0 : 3
            anchors.bottomMargin: btn.atBottom ? 3 : 0
            color: "transparent"; border.width: 1; border.color: root.phosphor
            visible: btn.containsMouse || root.expanded
        }
        Text {
            id: label
            anchors.centerIn: parent
            text: "[ CFG ]"
            color: root.phosphor
            opacity: btn.containsMouse || root.expanded ? 1 : 0.72
            font.family: "VT323"
            font.pixelSize: btn.fontPx
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.phosphor; shadowBlur: 0.55; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        }
    }

    // ------------------------------------------------------------ popup
    component Head: PC3.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        font.family: "VT323"
        font.pixelSize: Kirigami.Units.gridUnit * 1.25
        font.letterSpacing: 2
        color: root.phosphor
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.phosphor; opacity: 0.5 }
    }
    component Row2: RowLayout { Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing }
    component Lbl: PC3.Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 9; font.family: "VT323"; font.pixelSize: Kirigami.Units.gridUnit * 1.05 }
    component Val: PC3.Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 3; horizontalAlignment: Text.AlignRight; font.family: "VT323"; font.pixelSize: Kirigami.Units.gridUnit * 1.05 }

    fullRepresentation: PC3.ScrollView {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Math.min(col.implicitHeight + Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 40)
        contentWidth: availableWidth

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Kirigami.Units.smallSpacing
            enabled: root.loaded

            PC3.Label {
                Layout.fillWidth: true
                text: "POSEIDON OS // CONFIG"
                font.family: "VT323"; font.pixelSize: Kirigami.Units.gridUnit * 1.4
                color: root.phosphor
            }

            Head { text: "PHOSPHOR" }
            Row2 {
                Repeater {
                    model: [["GREEN", "green"], ["AMBER", "amber"], ["BLUE", "blue"]]
                    delegate: PC3.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData[0]
                        checkable: true
                        checked: root.variant === modelData[1]
                        // a restyle takes a moment; ignore repeat clicks and clicks on
                        // the phosphor that is already on instead of queueing more work
                        enabled: !root.switching
                        onClicked: {
                            if (root.switching) return;
                            root.variant = modelData[1];
                            root.switching = true;
                            switchGuard.restart();
                            root.run(root.bin + "poseidonos-theme\" " + modelData[1]);
                        }
                    }
                }
            }

            Head { text: "CLOCK" }
            Row2 {
                Lbl { text: "FORMAT" }
                Item { Layout.fillWidth: true }
                PC3.Button { text: "12-HOUR"; checkable: true; checked: !root.h24(); onClicked: root.setClock(false) }
                PC3.Button { text: "24-HOUR"; checkable: true; checked: root.h24(); onClicked: root.setClock(true) }
            }

            Head { text: "CRT OVERLAY" }
            Row2 {
                Lbl { text: "ENABLED" }
                Item { Layout.fillWidth: true }
                PC3.Switch {
                    id: crtSwitch
                    checked: root.crt.running
                    enabled: !crtGuard.running
                    onToggled: {
                        root.setCrt("running", checked);
                        crtTimer.stop();
                        root.run(root.bin + "poseidonos-crt\" " + (checked ? "start" : "stop"));
                        crtGuard.restart();   // then re-read the real state, see below
                    }
                    // interacting with a Switch clears the declarative binding, so the
                    // widget would keep showing what was asked for even if the overlay
                    // never came up.  Re-sync from the actual process state instead.
                    Connections {
                        target: root
                        function onCrtChanged() {
                            if (!crtGuard.running) crtSwitch.checked = root.crt.running;
                        }
                    }
                }
            }
            Row2 {
                Lbl { text: "SCANLINES" }
                PC3.Slider { Layout.fillWidth: true; from: 0; to: 0.5; value: root.crt.scanlines; onMoved: root.setCrt("scanlines", value) }
                Val { text: Math.round(root.crt.scanlines * 200) + "%" }
            }
            Row2 {
                Lbl { text: "VIGNETTE" }
                PC3.Slider { Layout.fillWidth: true; from: 0; to: 1; value: root.crt.vignette; onMoved: root.setCrt("vignette", value) }
                Val { text: Math.round(root.crt.vignette * 100) + "%" }
            }
            Row2 {
                PC3.CheckBox { text: "ROLLING BAND"; checked: root.crt.roll == 1; onToggled: root.setCrt("roll", checked ? 1 : 0) }
                PC3.CheckBox { text: "FLICKER"; checked: root.crt.flicker == 1; onToggled: root.setCrt("flicker", checked ? 1 : 0) }
            }

            Head { text: "WALLPAPER // DITHER" }
            Row2 {
                Lbl { text: "STYLE" }
                Item { Layout.fillWidth: true }
                PC3.Button { text: "WASTELAND MAP"; checkable: true; checked: root.wp("style", "map") !== "flow"; onClicked: root.setDesk("wallpaper", "style", "map") }
                PC3.Button { text: "FLOW"; checkable: true; checked: root.wp("style", "map") === "flow"; onClicked: root.setDesk("wallpaper", "style", "flow") }
            }
            Row2 {
                Lbl { text: "ANIMATE" }
                Item { Layout.fillWidth: true }
                PC3.Switch { checked: root.wp("animate", true); onToggled: root.setDesk("wallpaper", "animate", checked) }
            }
            Row2 {
                Lbl { text: "FLOW SPEED" }
                PC3.Slider { Layout.fillWidth: true; from: 0.01; to: 0.25; value: root.wp("speed", 0.05); onMoved: root.setDesk("wallpaper", "speed", Number(value.toFixed(3))) }
                Val { text: (root.wp("speed", 0.05) / 0.05).toFixed(1) + "x" }
            }
            Row2 {
                Lbl { text: "DOT SIZE" }
                PC3.Slider { Layout.fillWidth: true; from: 1; to: 6; stepSize: 1; snapMode: QQC2.Slider.SnapAlways; value: root.wp("dotSize", 2); onMoved: root.setDesk("wallpaper", "dotSize", value) }
                Val { text: root.wp("dotSize", 2) + " PX" }
            }
            Row2 {
                Lbl { text: "BRIGHTNESS" }
                PC3.Slider { Layout.fillWidth: true; from: 0.1; to: 1.0; value: root.wp("brightness", 0.45); onMoved: root.setDesk("wallpaper", "brightness", Number(value.toFixed(2))) }
                Val { text: Math.round(root.wp("brightness", 0.45) * 100) + "%" }
            }
            Row2 {
                Lbl { text: "DETAIL" }
                PC3.Slider { Layout.fillWidth: true; from: 1.5; to: 5.0; value: root.wp("frequency", 3.0); onMoved: root.setDesk("wallpaper", "frequency", Number(value.toFixed(2))) }
                Val { text: root.wp("frequency", 3.0).toFixed(1) }
            }
            Row2 {
                Lbl { text: "FRAME RATE" }
                PC3.Slider { Layout.fillWidth: true; from: 10; to: 60; stepSize: 5; snapMode: QQC2.Slider.SnapAlways; value: root.wp("fps", 30); onMoved: root.setDesk("wallpaper", "fps", value) }
                Val { text: root.wp("fps", 30) + " FPS" }
            }
            Row2 {
                Lbl { text: "EMBLEM" }
                Item { Layout.fillWidth: true }
                PC3.Switch { checked: root.wp("showEmblem", true); onToggled: root.setDesk("wallpaper", "showEmblem", checked) }
            }
            Row2 {
                Lbl { text: "ANIMATE EMBLEM" }
                Item { Layout.fillWidth: true }
                PC3.Switch { checked: root.wp("animateEmblem", true); onToggled: root.setDesk("wallpaper", "animateEmblem", checked) }
            }
            Row2 {
                Lbl { text: "EMBLEM SIZE" }
                PC3.Slider { Layout.fillWidth: true; from: 0.15; to: 0.8; value: root.wp("emblemSize", 0.42); onMoved: root.setDesk("wallpaper", "emblemSize", Number(value.toFixed(2))) }
                Val { text: Math.round(root.wp("emblemSize", 0.42) * 100) + "%" }
            }
            Row2 {
                Lbl { text: "EMBLEM IMAGE" }
                PC3.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    opacity: 0.75
                    text: root.wp("emblem", "") ? decodeURIComponent(root.wp("emblem", "").toString().replace("file://", "")).split("/").pop() : "DEFAULT"
                }
                PC3.Button { text: "CHOOSE"; onClicked: emblemDialog.open() }
                PC3.Button { text: "RESET"; enabled: root.wp("emblem", "") !== ""; onClicked: root.setDesk("wallpaper", "emblem", "") }
            }
            PC3.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.6
                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                text: "Any PNG/SVG with a transparent background works; it is recoloured and dithered into the flow."
            }

            Head { text: "WEATHER" }
            Row2 {
                PC3.TextField {
                    id: locField
                    Layout.fillWidth: true
                    placeholderText: "ZIP code or city"
                    text: root.we("location", "")
                    onAccepted: root.lookupLocation(text)
                }
                PC3.Button { text: "SET"; onClicked: root.lookupLocation(locField.text) }
            }
            Row2 {
                Lbl { text: "UNITS" }
                Item { Layout.fillWidth: true }
                PC3.Button { text: "°F"; checkable: true; checked: root.we("units", "F") === "F"; onClicked: root.setDesk("weather", "units", "F") }
                PC3.Button { text: "°C"; checkable: true; checked: root.we("units", "F") === "C"; onClicked: root.setDesk("weather", "units", "C") }
            }
            PC3.Label {
                Layout.fillWidth: true
                opacity: 0.75
                text: root.we("label", "") ? "> " + root.we("label", "").toUpperCase() : "> NO LOCATION"
                font.family: "VT323"; font.pixelSize: Kirigami.Units.gridUnit * 1.05
            }

            PC3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                visible: root.status.length > 0
                text: root.status
                font.family: "VT323"; font.pixelSize: Kirigami.Units.gridUnit * 1.05
                color: root.phosphor
            }
        }
    }

    FileDialog {
        id: emblemDialog
        title: "Choose emblem image"
        nameFilters: ["Images (*.png *.svg *.jpg *.jpeg *.webp)"]
        onAccepted: root.setDesk("wallpaper", "emblem", selectedFile.toString())
    }
}
