import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var tabList: Plasmoid.configuration.tabs.split(";;").map(function (t) {
        var i = t.indexOf("|");
        var head = i < 0 ? t : t.slice(0, i), cmd = i < 0 ? "" : t.slice(i + 1).trim();
        var c = head.indexOf(":");                       // "LABEL:hint|command"
        return { label: (c < 0 ? head : head.slice(0, c)).trim(), hint: c < 0 ? "" : head.slice(c + 1).trim(), cmd: cmd };
    }).filter(t => t.label.length > 0)
    property int current: -1

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    function launch(cmd) {
        if (!cmd) return;
        // unique suffix so the same command can be re-run while a previous instance is still "connected"
        runner.connectSource(cmd + " #" + Date.now());
    }

    fullRepresentation: Item {
        id: bar
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        Layout.fillHeight: true

        readonly property color phosphor: Kirigami.Theme.textColor
        // sized off a 2-gridUnit bar, so the tabs keep the same look in the taller taskbar
        readonly property real fontPx: Math.max(14, Math.round(Math.min(bar.height, Kirigami.Units.gridUnit * 2) * 0.62))
        // the tab bracket opens toward the screen: down from a top bar, up from a bottom one
        readonly property bool atBottom: Plasmoid.location === PlasmaCore.Types.BottomEdge

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Math.round(bar.fontPx * 0.9)
            leftPadding: spacing / 2
            rightPadding: spacing / 2

            Repeater {
                model: root.tabList
                delegate: Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool lit: mouse.containsMouse || root.current === index
                    width: label.implicitWidth + (hint.visible ? hint.implicitWidth + bar.fontPx * 0.35 : 0) + bar.fontPx
                    height: row.height

                    // tab bracket: two sides plus the edge nearest the screen
                    // border, open toward the desktop (bottom bar: open at the top)
                    Rectangle { visible: tab.lit; x: 0; y: bar.atBottom ? 0 : 3; width: 1; height: parent.height - 3; color: bar.phosphor }
                    Rectangle { visible: tab.lit; x: parent.width - 1; y: bar.atBottom ? 0 : 3; width: 1; height: parent.height - 3; color: bar.phosphor }
                    Rectangle { visible: tab.lit; x: 0; y: bar.atBottom ? parent.height - 4 : 3; width: parent.width; height: 1; color: bar.phosphor }

                    Text {
                        id: hint
                        visible: Plasmoid.configuration.showHints && tab.modelData.hint.length > 0
                        anchors.left: label.right
                        anchors.leftMargin: bar.fontPx * 0.35
                        anchors.baseline: label.baseline
                        text: tab.modelData.hint.toLowerCase()
                        color: mouse.pressed ? Kirigami.Theme.backgroundColor : bar.phosphor
                        opacity: tab.lit ? 0.85 : 0.45
                        font.family: Plasmoid.configuration.fontFamily
                        font.pixelSize: Math.round(bar.fontPx * 0.72)
                    }
                    Text {
                        id: label
                        x: bar.fontPx * 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        color: mouse.pressed ? Kirigami.Theme.backgroundColor : bar.phosphor
                        opacity: tab.lit ? 1.0 : 0.72
                        font.family: Plasmoid.configuration.fontFamily
                        font.pixelSize: bar.fontPx
                        font.letterSpacing: 1
                        layer.enabled: Plasmoid.configuration.glow
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: bar.phosphor
                            shadowBlur: 0.55
                            shadowOpacity: 0.9
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                            blurMax: 12
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: bar.atBottom ? 0 : 4
                        anchors.bottomMargin: bar.atBottom ? 4 : 0
                        visible: mouse.pressed
                        color: bar.phosphor
                        z: -1
                    }
                    PlasmaCore.ToolTipArea {
                        anchors.fill: parent
                        mainText: tab.modelData.label + (tab.modelData.hint ? " — " + tab.modelData.hint : "")
                        subText: tab.modelData.hint ? "Click to open " + tab.modelData.hint : ""
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.current = tab.index;
                                root.launch(tab.modelData.cmd);
                            }
                        }
                    }
                }
            }
        }
    }
}
