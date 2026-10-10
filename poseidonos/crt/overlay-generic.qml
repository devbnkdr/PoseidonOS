// X11 (and Wayland fallback when layer-shell QML is unavailable).
// X11: override-redirect, click-through window covering each screen.
// Wayland fallback: fullscreen + a KWin window rule (keep above, no focus, all desktops).
import QtQuick
import QtQuick.Window
import "args.js" as Args

Instantiator {
    id: inst
    readonly property var opts: Args.parse(Qt.application.arguments)
    readonly property bool wayland: Qt.platform.pluginName.indexOf("wayland") === 0
    model: Qt.application.screens
    delegate: Window {
        required property var modelData
        screen: modelData
        title: "POSEIDONOS_CRT"
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput
               | Qt.WindowDoesNotAcceptFocus | Qt.Tool
               | (inst.wayland ? 0 : Qt.X11BypassWindowManagerHint)
        x: modelData.virtualX
        y: modelData.virtualY
        width: modelData.width
        height: modelData.height
        visibility: inst.wayland ? Window.FullScreen : Window.Windowed
        visible: true
        CrtLayer {
            anchors.fill: parent
            tint: inst.opts.tint
            scanlines: inst.opts.scanlines
            vignette: inst.opts.vignette
            roll: inst.opts.roll
            flicker: inst.opts.flicker
        }
    }
}
