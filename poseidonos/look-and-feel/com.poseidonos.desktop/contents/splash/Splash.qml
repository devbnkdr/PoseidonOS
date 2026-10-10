import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#030a05"
    property int stage
    readonly property color phosphor: Kirigami.Theme.textColor.hslLightness > 0.3 ? Kirigami.Theme.textColor : "#1aff80"

    readonly property var bootLines: [
        "POSEIDON OS",
        "",
        "> INITIALIZING KERNEL ........... OK",
        "> MOUNTING STORAGE .............. OK",
        "> STARTING WINDOW MANAGER ....... OK",
        "> LOADING PLASMA SHELL .......... OK",
        "> CALIBRATING PHOSPHOR .......... OK",
        "",
        "WELCOME, OPERATOR."
    ]
    property int shown: 0

    Timer {
        interval: 140; repeat: true; running: root.shown < root.bootLines.length
        onTriggered: root.shown++
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: parent.width * 0.08
        anchors.topMargin: parent.height * 0.12
        spacing: 4
        Repeater {
            model: root.shown
            Text {
                text: root.bootLines[index]
                color: root.phosphor
                font.family: "VT323"
                font.pixelSize: Math.round(root.height / 30)
            }
        }
        Text {
            text: "█"
            color: root.phosphor
            font.family: "VT323"
            font.pixelSize: Math.round(root.height / 30)
            SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0; duration: 400 } NumberAnimation { to: 1; duration: 400 } }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.12
        color: root.phosphor
        font.family: "VT323"
        font.pixelSize: Math.round(root.height / 26)
        text: {
            var n = 24, f = Math.min(n, Math.round(n * root.stage / 6));
            return "[" + "█".repeat(f) + "·".repeat(n - f) + "]";
        }
    }

    // scanlines
    Column {
        anchors.fill: parent
        Repeater {
            model: Math.ceil(root.height / 3)
            Rectangle { width: root.width; height: 3; color: "transparent"
                Rectangle { width: parent.width; height: 1; color: "black"; opacity: 0.35 } }
        }
    }
}
