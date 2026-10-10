#version 440
// Pass 2 of 2 (the per-dot pass). The noise field now comes from noise.frag.
// Port of "flow2.html" (Homebrew Wallpapers) to a Qt 6 ShaderEffect.
// Same Perlin fbm, triple domain warp and Bayer 8x8 dots; the three-colour
// ramp is replaced by a phosphor ramp and an emblem is dithered into the field.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;      // size of the dot grid (screen / dotSize)
    float time;
    float waveSpeed;
    float waveFrequency;
    float waveAmplitude;
    float colorSpread;
    float colorShift;
    float flowOpacity;
    vec4 phosphor;
    vec4 background;
    float emblemSize;     // emblem height as fraction of screen height
    float emblemAspect;   // emblem width / height
    float emblemLevel;    // dither density of the emblem (0..1)
    float emblemY;        // vertical centre (0 = top, 1 = bottom)
    float mapMode;        // 0 = original flow, 1 = wasteland map
};
layout(binding = 1) uniform sampler2D emblem;
layout(binding = 2) uniform sampler2D flowField;   // r = raw fbm value, g = terrain height

float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(a * 0.5) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(a * 0.5) * 0.25 + bayer2(a); }

float hash21(vec2 c) {
    vec3 p3 = fract(vec3(c.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    // one fragment == one dot (the item is rendered at dot resolution and upscaled)
    vec2 dotCoord = floor(qt_TexCoord0 * resolution);
    vec2 uv = (dotCoord + 0.5) / resolution;          // 0..1, y down
    vec2 uvGL = vec2(uv.x, 1.0 - uv.y);                 // flow2 used GL (y up)
    vec2 p = uvGL - 0.5;
    p.x *= resolution.x / resolution.y;

    vec4 field = texture(flowField, uv);                // precomputed by noise.frag
    float density = clamp(field.r * 2.447 - 1.169, 0.0, 1.0);
    float feature = 0.0;     // map overlays that sit on top of the terrain (grid, contours, markers)

    if (mapMode > 0.5) {
        // ---- WASTELAND MAP: the flow becomes terrain read on a retro survey map
        // contour lines (isolines of the terrain height), every 4th one is an index contour
        // smooth, low-frequency height field so the isolines read as clean terrain contours
        float hgt = (field.g - 0.5) * 4.0;
        float h = hgt * 7.0;
        float fw = clamp(fwidth(h) * 1.5, 0.02, 0.25);
        float c1 = smoothstep(0.5 - fw, 0.5, abs(fract(h) - 0.5));
        float idx = step(3.5, mod(floor(h + 0.5), 4.0));
        float contour = c1 * (0.55 + 0.45 * idx);
        // terrain fill becomes a faint wash so the contours read first
        density = density * 0.3;
        // survey grid: dashed lines every 64 dots, with tick crosses at intersections
        vec2 gm = mod(dotCoord, 64.0);
        float gline = (step(gm.x, 0.5) + step(gm.y, 0.5)) * step(mod(dotCoord.x + dotCoord.y, 4.0), 1.5);
        float cross = step(min(gm.x, 64.0 - gm.x), 3.5) * step(min(gm.y, 64.0 - gm.y), 0.5)
                    + step(min(gm.y, 64.0 - gm.y), 3.5) * step(min(gm.x, 64.0 - gm.x), 0.5);
        float grid = clamp(gline * 0.35 + cross * 0.9, 0.0, 1.0);
        // radar sweep around the screen centre with a fading tail
        vec2 rc = p;
        float ang = atan(rc.y, rc.x);
        float sweep = mod(time * 0.5 - ang, 6.2831853);
        float radar = exp(-sweep * 2.2) * smoothstep(1.2, 0.2, length(rc));
        float rw = clamp(fwidth(length(rc) * 4.0) * 1.2, 0.002, 0.1);
        float rings = smoothstep(0.5 - rw, 0.5, abs(fract(length(rc) * 4.0) - 0.5)) * 0.4 * step(length(rc), 0.8);
        // location markers: sparse squares that blink, brighter when the sweep passes
        vec2 cell = floor(dotCoord / 40.0);
        float hsh = hash21(cell);
        vec2 cc = (cell + 0.5) * 40.0 + (vec2(hash21(cell + 7.0), hash21(cell + 13.0)) - 0.5) * 20.0;
        vec2 dm = abs(dotCoord - cc);
        float box = step(max(dm.x, dm.y), 3.5) * (1.0 - step(max(dm.x, dm.y), 1.5));
        float blink = step(0.5, fract(time * 0.7 + hsh * 3.0));
        float marker = step(0.955, hsh) * box * (0.6 + 0.4 * blink);
        feature = max(max(contour, grid), max(marker, rings));
        density = clamp(density + radar * 0.45 + feature * 0.0, 0.0, 1.0);
        density = max(density, feature);
    }

    // emblem, aspect-correct, centred horizontally
    float aspect = resolution.x / resolution.y;
    vec2 e = vec2((uv.x - 0.5) * aspect / (emblemSize * emblemAspect) + 0.5,
                  (uv.y - emblemY) / emblemSize + 0.5);
    float em = 0.0;
    if (e.x > 0.0 && e.x < 1.0 && e.y > 0.0 && e.y < 1.0) {
        vec4 c = texture(emblem, e);                    // premultiplied
        float lum = max(max(c.r, c.g), c.b);
        em = c.a * mix(0.55, 1.0, lum / max(c.a, 1e-3));
    }
    // soft halo keeps the flow from crossing the emblem edge too sharply
    float halo = smoothstep(0.62, 0.0, length(vec2((e.x - 0.5) * emblemAspect, e.y - 0.5)));
    density = mix(density, density * 0.35, halo * 0.8);
    float emDensity = em * emblemLevel;
    float d = max(density, emDensity);

    float dotOn = step(bayer8(dotCoord.yx) + 0.001, d);

    float gradient = clamp(density * colorSpread + uvGL.y * 0.45
                           + 0.18 * sin(time * colorShift + uvGL.x * 2.4), 0.0, 1.0);
    vec3 low  = phosphor.rgb * 0.45;
    vec3 high = mix(phosphor.rgb, vec3(1.0), 0.35);
    vec3 tint = mix(low, phosphor.rgb, smoothstep(0.0, 0.55, gradient));
    tint = mix(tint, high, smoothstep(0.45, 1.0, gradient));

    float shade = mix(0.62, 1.0, density);
    vec3 flowCol = tint * (flowOpacity * shade);
    vec3 emCol = mix(phosphor.rgb, high, 0.4);
    vec3 col = emDensity >= density ? emCol : flowCol;
    vec3 outCol = mix(background.rgb, col, dotOn);
    fragColor = vec4(outCol, 1.0) * qt_Opacity;
}
