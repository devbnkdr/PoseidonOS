import QtQuick

// Draws the CRT treatment on top of whatever is below it.
// Everything is semi-transparent black / phosphor tint, and the window never takes input.
Item {
    id: crt
    property color tint: "#1aff80"
    property real scanlines: 0.14     // 0..1 darkness of each scanline
    property real vignette: 0.55      // 0..1 corner darkening
    property bool roll: true          // slow bright band rolling down the screen
    property bool flicker: true

    Image {
        anchors.fill: parent
        source: "scanlines.png"
        fillMode: Image.Tile
        smooth: false
        opacity: crt.scanlines
    }
    Image {
        anchors.fill: parent
        source: "vignette.png"
        smooth: true
        opacity: crt.vignette
    }
    Rectangle {
        id: band
        visible: crt.roll
        width: parent.width
        height: Math.round(parent.height * 0.18)
        y: -height
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(crt.tint.r, crt.tint.g, crt.tint.b, 0.045) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        // Stepped ~15x a second: a vsync-rate animation here made KWin recomposite a
        // strip of every screen on every refresh, forever. At this speed (one pass per
        // 11 s) the steps are only a few pixels, so it looks the same.
        Timer {
            interval: 66
            repeat: true
            running: crt.roll
            property double t0: Date.now()
            onTriggered: band.y = Math.round(-band.height + ((Date.now() - t0) % 11000) / 11000 * (crt.height + band.height))
        }
    }
    // Flicker sits at zero opacity and only pulses now and then, so the
    // compositor is not repainting the whole screen several times a second.
    Rectangle {
        id: flick
        anchors.fill: parent
        color: "black"
        opacity: 0
        visible: crt.flicker && opacity > 0
        SequentialAnimation {
            id: pulse
            NumberAnimation { target: flick; property: "opacity"; to: 0.035; duration: 60 }
            NumberAnimation { target: flick; property: "opacity"; to: 0.0; duration: 110 }
        }
        Timer {
            id: flickTimer
            running: crt.flicker; repeat: false
            interval: 1400 + Math.random() * 3200
            onTriggered: { pulse.restart(); interval = 1400 + Math.random() * 3200; restart(); }
        }
    }
}
