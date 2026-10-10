.pragma library
function parse(argv) {
    var o = { tint: "#1aff80", scanlines: 0.14, vignette: 0.55, roll: true, flicker: true };
    for (var i = 0; i < argv.length - 1; i++) {
        var k = argv[i], v = argv[i + 1];
        if (k === "--tint") o.tint = v;
        else if (k === "--scanlines") o.scanlines = Number(v);
        else if (k === "--vignette") o.vignette = Number(v);
        else if (k === "--roll") o.roll = v === "1" || v === "true";
        else if (k === "--flicker") o.flicker = v === "1" || v === "true";
    }
    return o;
}
