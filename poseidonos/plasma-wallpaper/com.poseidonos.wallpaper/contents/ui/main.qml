import QtQuick
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

WallpaperItem {
    id: root

    // ~/.config/poseidonos/desktop.json, written by the [ CFG ] popup
    property var cfg: ({})
    readonly property var wp: cfg.wallpaper || ({})
    function num(v, d) { return (v === undefined || v === null || isNaN(Number(v))) ? d : Number(v); }

    readonly property real dotSize: Math.max(1, Math.round(num(wp.dotSize, 2)))
    readonly property bool animate: wp.animate !== false
    readonly property int fps: Math.max(5, Math.min(60, num(wp.fps, 30)))
    readonly property int emblemFps: Math.min(fps, 20)
    // the noise field drifts very slowly, so it is recomputed at most 15x a second
    readonly property int flowFps: Math.min(fps, 15)
    readonly property real flowT: Math.floor(t * flowFps) / flowFps
    // emblem texture only needs to be about as big as it appears on the dot grid
    readonly property int emblemPx: Math.max(128, Math.min(512,
        Math.ceil(root.height * num(wp.emblemSize, 0.42) / dotSize * 1.25)))
    readonly property color phosphor: Kirigami.Theme.textColor
    readonly property color bgColor: Kirigami.Theme.backgroundColor
    property real t: 0

    // desktop.json is re-read when the [ CFG ] panel saves it (inotify via ConfigWatch);
    // the slow poll is only a safety net.
    readonly property string cfgCmd: "cat \"$HOME/.config/poseidonos/desktop.json\" 2>/dev/null #wp"
    ConfigWatch { onChanged: { cfgSrc.disconnectSource(root.cfgCmd); cfgSrc.connectSource(root.cfgCmd); } }
    P5Support.DataSource {
        id: cfgSrc
        engine: "executable"
        connectedSources: [root.cfgCmd]
        interval: 60000
        onNewData: (source, data) => {
            try {
                var o = JSON.parse(data.stdout);
                if (JSON.stringify(o) !== JSON.stringify(root.cfg)) root.cfg = o;
            } catch (e) {}
        }
    }

    // pause everything while a maximized / fullscreen window hides this screen
    // (set "pauseWhenCovered": false in desktop.json to keep animating)
    CoverWatch { id: cover; active: root.wp.pauseWhenCovered !== false }
    readonly property bool live: root.visible && !cover.covered

    Timer {
        property double start: Date.now()
        running: root.animate && root.live
        repeat: true
        interval: Math.round(1000 / root.fps)
        onTriggered: root.t = (Date.now() - start) / 1000
    }

    Rectangle { anchors.fill: parent; color: root.bgColor }

    // ---- emblem: the PoseidonOS trident on a spinning globe.
    // A custom emblem image picked in [ CFG ] replaces it and gently breathes instead.
    readonly property bool customEmblem: !!root.wp.emblem
    readonly property bool animEmblem: root.animate && root.wp.animateEmblem !== false
    Item {
        id: emblemImg
        width: root.emblemPx
        height: root.emblemPx
        readonly property real implicitWidthRatio: root.customEmblem && custom.implicitHeight > 0 ? custom.implicitWidth / custom.implicitHeight : 1.0
        GlobeEmblem {
            id: globe
            visible: !root.customEmblem
            anchors.fill: parent
            spinning: root.animEmblem && !root.customEmblem
            // globe redraws are CPU work (JS Canvas), so cap them at 20 fps
            time: Math.floor(root.t * root.emblemFps) / root.emblemFps
        }
        Image {
            id: custom
            visible: root.customEmblem
            anchors.fill: parent
            source: root.customEmblem ? root.wp.emblem : ""
            sourceSize.height: 512
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }
    ShaderEffectSource {
        id: emblemTex
        sourceItem: emblemImg
        hideSource: true
        visible: false
        smooth: true
        live: true
    }
    // slow "breathing" of the emblem's dot density (1.0 -> 0.78 -> 1.0 every 5.2 s).
    // Computed from the frame-capped clock so it never forces extra redraws.
    readonly property real pulse: root.animEmblem ? 0.89 + 0.11 * Math.cos(root.t * 2 * Math.PI / 5.2) : 1.0

    // pass 1: the noise field at reduced resolution, half-float, bilinear-sampled by pass 2.
    // Map style (default) only shows the flow as a faint wash, so 1/4 is indistinguishable;
    // plain flow style shows the sharp ridges, so it keeps 1/2.
    readonly property int fieldDiv: root.wp.style === "flow" ? 2 : 4
    ShaderEffect {
        id: noisePass
        width: Math.max(8, Math.ceil(lowres.width / root.fieldDiv))
        height: Math.max(8, Math.ceil(lowres.height / root.fieldDiv))
        property real aspect: lowres.width / Math.max(1, lowres.height)
        property real time: root.flowT
        property real waveSpeed: root.num(root.wp.speed, 0.05)
        property real waveFrequency: root.num(root.wp.frequency, 3.0)
        property real waveAmplitude: root.num(root.wp.amplitude, 0.3)
        fragmentShader: Qt.resolvedUrl("../shaders/noise.frag.qsb")
    }
    ShaderEffectSource {
        id: flowTex
        sourceItem: noisePass
        hideSource: true
        visible: false
        smooth: true
        live: true
        format: ShaderEffectSource.RGBA16F
    }

    // pass 2: rendered at dot resolution, upscaled with nearest filtering
    Item {
        id: lowres
        width: Math.ceil(root.width / root.dotSize)
        height: Math.ceil(root.height / root.dotSize)
        transformOrigin: Item.TopLeft
        scale: root.dotSize
        layer.enabled: true
        layer.smooth: false

        ShaderEffect {
            anchors.fill: parent
            property size resolution: Qt.size(lowres.width, lowres.height)
            property real time: root.t
            property real waveSpeed: root.num(root.wp.speed, 0.05)
            property real waveFrequency: root.num(root.wp.frequency, 3.0)
            property real waveAmplitude: root.num(root.wp.amplitude, 0.3)
            property real colorSpread: 1.0
            property real colorShift: 0.15
            property real flowOpacity: root.num(root.wp.brightness, 0.45)
            property color phosphor: root.phosphor
            property color background: root.bgColor
            property real emblemSize: root.num(root.wp.emblemSize, 0.42)
            property real emblemAspect: 1.0
            property real emblemLevel: root.wp.showEmblem === false ? 0.0 : root.num(root.wp.emblemLevel, 0.9) * root.pulse
            property real emblemY: root.num(root.wp.emblemY, 0.46)
            property real mapMode: root.wp.style === "flow" ? 0.0 : 1.0
            property var emblem: emblemTex
            property var flowField: flowTex
            fragmentShader: Qt.resolvedUrl("../shaders/flow.frag.qsb")
        }
    }

    // footer: a line of slowly changing hex codes
    Item {
        id: footer
        // only the bottom strip is layered + glow-blurred, not a full-screen texture
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.height * 0.075 + px * 3
        readonly property real px: Math.max(14, Math.round(root.height / 42))
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.phosphor
            shadowBlur: 0.6
            shadowOpacity: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        Text {
            id: hexLine
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: root.width * 0.04
            anchors.bottomMargin: root.height * 0.075
            color: Qt.rgba(root.phosphor.r, root.phosphor.g, root.phosphor.b, 0.32)
            font.family: "VT323"
            font.pixelSize: footer.px
            function scramble() {
                var s = [];
                for (var i = 0; i < 9; i++)
                    s.push("0x" + ("000" + Math.floor(Math.random() * 65536).toString(16).toUpperCase()).slice(-4));
                text = s.join(" ");
            }
            Component.onCompleted: scramble()
            Timer { interval: 4000; running: root.animate && root.live; repeat: true; onTriggered: hexLine.scramble() }
        }
    }
}
