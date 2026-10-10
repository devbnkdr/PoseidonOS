#version 440
// PoseidonOS wallpaper, pass 1 of 2: the expensive part (Perlin fbm with a triple
// domain warp = 20 noise lookups per sample, plus the map height field).
// Rendered into a small half-float texture (1/4 of the dot grid in each direction)
// at a reduced rate; flow.frag samples it with bilinear filtering. The field is
// smooth, so this looks the same as computing it per dot but costs ~1/16 as much.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;         // dot grid width / height
    float time;
    float waveSpeed;
    float waveFrequency;
    float waveAmplitude;
};

vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec2 fade(vec2 t) { return t*t*t*(t*(t*6.0-15.0)+10.0); }

float cnoise(vec2 P) {
    vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
    vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
    Pi = mod289(Pi);
    vec4 ix = Pi.xzxz;
    vec4 iy = Pi.yyww;
    vec4 fx = Pf.xzxz;
    vec4 fy = Pf.yyww;
    vec4 i = permute(permute(ix) + iy);
    vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0;
    vec4 gy = abs(gx) - 0.5;
    vec4 tx = floor(gx + 0.5);
    gx = gx - tx;
    vec2 g00 = vec2(gx.x, gy.x);
    vec2 g10 = vec2(gx.y, gy.y);
    vec2 g01 = vec2(gx.z, gy.z);
    vec2 g11 = vec2(gx.w, gy.w);
    vec4 norm = taylorInvSqrt(vec4(dot(g00,g00), dot(g01,g01), dot(g10,g10), dot(g11,g11)));
    g00 *= norm.x; g01 *= norm.y; g10 *= norm.z; g11 *= norm.w;
    float n00 = dot(g00, vec2(fx.x, fy.x));
    float n10 = dot(g10, vec2(fx.y, fy.y));
    float n01 = dot(g01, vec2(fx.z, fy.z));
    float n11 = dot(g11, vec2(fx.w, fy.w));
    vec2 fadeXY = fade(Pf.xy);
    vec2 nx = mix(vec2(n00, n01), vec2(n10, n11), fadeXY.x);
    return 2.3 * mix(nx.x, nx.y, fadeXY.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amp = 1.0;
    for (int i = 0; i < 4; i++) {
        value += amp * abs(cnoise(p));
        p *= waveFrequency;
        amp *= waveAmplitude;
    }
    return value;
}

void main() {
    vec2 uv = qt_TexCoord0;                             // 0..1, y down
    vec2 uvGL = vec2(uv.x, 1.0 - uv.y);
    vec2 p = uvGL - 0.5;
    p.x *= aspect;

    float drift = time * waveSpeed * 0.8;
    vec2 q = vec2(fbm(p + vec2(0.0, 1.7)), fbm(p + vec2(5.2, 9.3)));
    vec2 r = vec2(
        fbm(p + 3.0 * q + vec2(1.7, 9.2) - vec2(drift, 0.0)),
        fbm(p + 3.0 * q + vec2(8.3, 2.8) - vec2(0.0, drift)));
    float noiseValue = fbm(p + 2.4 * r);

    // smooth, low-frequency terrain height for the map contours (decoded in flow.frag)
    vec2 tp = p * 1.6 + vec2(time * waveSpeed * 0.15, 0.0);
    float hgt = 0.55 * cnoise(tp) + 0.28 * cnoise(tp * 2.1 + 3.7) + 0.12 * cnoise(tp * 4.3 + 9.1);

    // raw fbm value: flow.frag applies the steep contrast curve AFTER bilinear sampling,
    // which keeps the ridges crisp at the reduced resolution
    fragColor = vec4(noiseValue, hgt * 0.25 + 0.5, 0.0, 1.0);
}
