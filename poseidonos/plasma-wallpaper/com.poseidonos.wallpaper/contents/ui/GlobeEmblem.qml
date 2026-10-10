import QtQuick

// PoseidonOS emblem: a trident coiled around a spinning wireframe globe like a snake.
// The shaft follows a tilted orbit hugging the sphere with a slithering wiggle; the
// three-pronged head leads the way. Parts behind the globe are hidden by it.
// Drawn white-on-transparent; the wallpaper shader recolours and dithers it.
Canvas {
    id: cv
    width: 512
    height: 512
    // Driven by the wallpaper's frame-capped clock (seconds), so it respects the
    // fps setting instead of repainting at the monitor's refresh rate.
    property real time: 0
    property bool spinning: true
    readonly property real phase: spinning ? ((time / 9) % 1) * Math.PI / 3 : 0            // globe spin
    readonly property real slide: spinning ? ((time / 26) % 1) * Math.PI * 2 / 0.42 : 0     // travel along the orbit
    // rasterize on Canvas's own thread instead of plasmashell's main thread
    renderStrategy: Canvas.Threaded

    onPhaseChanged: if (visible) requestPaint()
    onSlideChanged: if (visible) requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onWidthChanged: requestPaint()

    readonly property real cx: 256
    readonly property real cy: 256
    readonly property real rad: 168

    function globe(ctx) {
        ctx.lineWidth = 10;
        ctx.beginPath(); ctx.arc(cx, cy, rad, 0, Math.PI * 2); ctx.stroke();
        ctx.save();
        ctx.beginPath(); ctx.arc(cx, cy, rad - 4, 0, Math.PI * 2); ctx.clip();
        ctx.lineWidth = 4;
        [-60, -30, 0, 30, 60].forEach(function (lat) {
            var a = lat * Math.PI / 180, y = cy - rad * Math.sin(a), hw = rad * Math.cos(a);
            ctx.beginPath(); ctx.moveTo(cx - hw, y); ctx.lineTo(cx + hw, y); ctx.stroke();
        });
        for (var i = 0; i < 6; i++) {
            var lon = cv.phase + i * Math.PI / 6;
            var rx = Math.abs(rad * Math.sin(lon));
            ctx.lineWidth = rx < rad * 0.2 ? 5 : 4;
            ctx.beginPath(); ctx.ellipse(cx - rx, cy - rad, rx * 2, rad * 2); ctx.stroke();
        }
        ctx.restore();
    }

    // point on the coil: a helix that winds around the sphere while drifting between the
    // northern and southern latitudes, with a slithering wiggle. u = distance along the body.
    function coil(u) {
        var r = rad + 12;
        var lon = u * 1.0;
        var lat = 0.78 * Math.sin(u * 0.42) + 0.10 * Math.sin(5 * u - 4 * cv.slide);
        var x = Math.cos(lat) * Math.sin(lon), y = Math.sin(lat), z = Math.cos(lat) * Math.cos(lon);
        // tip the whole coil slightly towards the viewer so both hemispheres read
        var t = 0.35;
        var y2 = y * Math.cos(t) - z * Math.sin(t), z2 = y * Math.sin(t) + z * Math.cos(t);
        return { x: cx + r * x, y: cy - r * y2, z: z2 };
    }

    // Segments are batched into a few polylines (one per width step) instead of one
    // beginPath/stroke per segment: ~20 draw calls per pass instead of ~160.
    function shaft(ctx, pts, front, knock) {
        var steps = 6, cur = -1;
        var paths = [];
        for (var k = 0; k < steps; k++) paths.push([]);
        for (var i = 1; i < pts.length; i++) {
            var a = pts[i - 1], b = pts[i];
            if ((a.z + b.z >= 0) !== front) { cur = -1; continue; }
            var bucket = Math.min(steps - 1, Math.floor(i / pts.length * steps));
            if (bucket !== cur) { paths[bucket].push([a]); cur = bucket; }
            var run = paths[bucket];
            run[run.length - 1].push(b);
        }
        for (var s = 0; s < steps; s++) {
            if (!paths[s].length) continue;
            var w = 6 + 10 * ((s + 0.5) / steps);            // tail thin -> head thick
            ctx.lineWidth = knock ? w + 18 : w;
            ctx.beginPath();
            for (var r = 0; r < paths[s].length; r++) {
                var run2 = paths[s][r];
                ctx.moveTo(run2[0].x, run2[0].y);
                for (var j = 1; j < run2.length; j++) ctx.lineTo(run2[j].x, run2[j].y);
            }
            ctx.stroke();
        }
    }

    function head(ctx, pts, grow) {
        var p = pts[pts.length - 1], q = pts[pts.length - 4];
        var ang = Math.atan2(p.y - q.y, p.x - q.x);
        var sc = 0.95 + 0.3 * p.z;                          // perspective
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(ang);
        ctx.scale(sc, sc);
        var g = grow, h = 34, len = 58, sw = 11;
        // crossbar, three prongs forward (+x), arrow tips
        ctx.fillRect(-sw / 2 - g, -h - sw / 2 - g, sw + 2 * g, 2 * h + sw + 2 * g);
        [-h, 0, h].forEach(function (y) {
            var l = y === 0 ? len + 14 : len;
            ctx.fillRect(-g, y - sw / 2 - g, l + 2 * g, sw + 2 * g);
            ctx.beginPath();
            ctx.moveTo(l - 4 - g, y - sw * 1.6 - g);
            ctx.lineTo(l + 26 + g, y);
            ctx.lineTo(l - 4 - g, y + sw * 1.6 + g);
            ctx.closePath(); ctx.fill();
        });
        ctx.restore();
        return p.z >= 0;
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.scale(width / 512, height / 512);   // artwork is authored in 512x512 units
        ctx.strokeStyle = "white";
        ctx.fillStyle = "white";
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        // ~1.4 turns of coil behind the head
        var pts = [], n = 110, span = Math.PI * 3.2;
        for (var i = 0; i <= n; i++) pts.push(coil(cv.slide + (i / n - 1) * span));
        var headFront = pts[n].z >= 0;

        // back half: dimmer, then hidden inside the globe's disc
        ctx.globalAlpha = 0.6;
        shaft(ctx, pts, false, false);
        if (!headFront) head(ctx, pts, 0);
        ctx.globalAlpha = 1.0;
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath(); ctx.arc(cx, cy, rad + 5, 0, Math.PI * 2); ctx.fill();
        ctx.globalCompositeOperation = "source-over";

        globe(ctx);

        // front half: cut a gap in the globe lines, then draw the coil and head on top
        ctx.globalCompositeOperation = "destination-out";
        shaft(ctx, pts, true, true);
        if (headFront) head(ctx, pts, 9);
        ctx.globalCompositeOperation = "source-over";
        shaft(ctx, pts, true, false);
        if (headFront) head(ctx, pts, 0);
    }
}
