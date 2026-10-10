// Wayland (Plasma 6): one layer-shell surface per screen on the OVERLAY layer,
// above panels and fullscreen apps, never focusable, click-through.
import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import "args.js" as Args

Instantiator {
    id: inst
    readonly property var opts: Args.parse(Qt.application.arguments)
    model: Qt.application.screens
    delegate: Window {
        required property var modelData
        screen: modelData
        title: "POSEIDONOS_CRT"
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
        LayerShell.Window.scope: "poseidonos-crt"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        width: modelData.width
        height: modelData.height
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
