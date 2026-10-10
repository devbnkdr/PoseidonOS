// Real interactive shell via QMLTermWidget (pacman -S qmltermwidget).
// If the import fails, the HUD falls back to TermConsole.qml.
// Copy / paste: Ctrl+Shift+C / Ctrl+Shift+V (or the [ COPY ] [ PASTE ] buttons).
import QtQuick
import QtQuick.Effects
import QMLTermWidget

Item {
    id: tr
    property color phosphor: "#1aff80"
    property int fpx: 18
    readonly property bool real: true
    function focusInput() { term.forceActiveFocus(); }
    function copy() { term.copyClipboard(); term.forceActiveFocus(); }
    function paste() { term.pasteClipboard(); term.forceActiveFocus(); }
    function restart() { sess.clearScreen(); sess.startShellProgram(); term.forceActiveFocus(); }

    QMLTermWidget {
        id: term
        anchors.fill: parent
        focus: true
        font.family: "VT323"
        font.pixelSize: Math.max(12, tr.fpx)
        colorScheme: "WhiteOnBlack"
        smooth: true
        session: QMLTermSession {
            id: sess
            onFinished: restartTimer.start()      // `exit` just gives you a fresh shell
        }
        Component.onCompleted: {
            sess.startShellProgram();
            term.forceActiveFocus();
        }
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (e) => {
            var cs = (e.modifiers & Qt.ControlModifier) && (e.modifiers & Qt.ShiftModifier);
            if (cs && e.key === Qt.Key_C) { term.copyClipboard(); e.accepted = true; }
            else if (cs && e.key === Qt.Key_V) { term.pasteClipboard(); e.accepted = true; }
            else if ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Insert) { term.pasteClipboard(); e.accepted = true; }
        }
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: tr.phosphor; brightness: 0.1 }
    }
    // desktop widgets don't get keyboard focus by themselves: grab it on click or hover
    TapHandler { acceptedButtons: Qt.LeftButton; gesturePolicy: TapHandler.DragThreshold; onTapped: term.forceActiveFocus() }
    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: { term.pasteSelection(); term.forceActiveFocus(); } }
    HoverHandler { onHoveredChanged: if (hovered) term.forceActiveFocus() }
    Timer { id: restartTimer; interval: 300; onTriggered: { sess.clearScreen(); sess.startShellProgram(); } }
}
