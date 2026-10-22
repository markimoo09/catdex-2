#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Noise helpers

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * valueNoise(p);
        p *= 2.03;
        amp *= 0.5;
    }
    return v;
}

// MARK: - Film grain (colorEffect on a white fill, blended as overlay)

[[stitchable]] half4 grain(float2 position, half4 color, float amount) {
    float n = hash21(floor(position));
    half v = half(n);
    return half4(v, v, v, 1.0) * half(amount) * color.a;
}

// MARK: - Foil sheen (colorEffect on a white fill, composited over art)
// Iridescent bands plus a specular streak that both slide with device tilt.

[[stitchable]] half4 foilSheen(float2 position, half4 color, float2 size, float2 tilt, float strength, float hueShift, float iridescence, float warmth) {
    float2 uv = position / max(size, float2(1.0));
    float band = uv.x * 1.15 + uv.y * 0.85 + tilt.x * 0.9 - tilt.y * 0.7;
    float3 rainbow = 0.5 + 0.5 * cos(6.28318 * (band * 1.4 + hueShift + float3(0.0, 0.33, 0.67)));
    // Each marque has its own metal: warm gilt, cool silver, or iridescent platinum.
    float3 metal = mix(float3(0.86, 0.9, 1.0), float3(1.0, 0.84, 0.55), warmth);
    float3 sheen = mix(metal, rainbow * 0.5 + metal * 0.5, iridescence);

    float streakCenter = 0.5 + tilt.x * 0.55 + tilt.y * 0.25;
    float d = abs((uv.x * 0.6 + uv.y * 0.4) - streakCenter);
    float spec = smoothstep(0.16, 0.0, d);
    float broad = smoothstep(0.5, 0.0, d) * 0.35;

    float3 rgb = sheen * (broad + spec * 0.8);
    float alpha = clamp((broad + spec * 0.55) * strength, 0.0, 1.0);
    return half4(half3(rgb * strength), half(alpha)) * color.a;
}

// MARK: - Brushed metal (colorEffect on the patron card fill)

[[stitchable]] half4 brushedMetal(float2 position, half4 color, float2 size, float2 tilt) {
    float streak = hash21(float2(floor(position.y * 0.9), floor(position.x / 90.0)));
    float fine = hash21(floor(position * float2(0.25, 1.0)));
    float lines = (streak * 0.7 + fine * 0.3) - 0.5;
    float2 uv = position / max(size, float2(1.0));
    float sweep = smoothstep(0.35, 0.0, abs(uv.x - (0.5 + tilt.x * 0.8)));
    half3 rgb = color.rgb + half(lines * 0.06) * color.a + half(sweep * 0.12) * color.a;
    return half4(rgb, color.a);
}

// MARK: - Gilded dissolve (layerEffect)
// Burns the layer away along an fbm front; the burning edge glows gold.

[[stitchable]] half4 gildedDissolve(float2 position, SwiftUI::Layer layer, float2 size, float progress) {
    half4 c = layer.sample(position);
    float2 uv = position / max(size, float2(1.0));
    // Burn inward from the edges so the subject in the centre goes last.
    float radial = length(uv - 0.5) * 1.1;
    float n = fbm(position / 26.0) * 0.65 + (1.0 - radial) * 0.35;
    float front = progress * 1.25 - 0.1;
    float width = 0.07;
    if (n < front - width) {
        return half4(0.0);
    }
    if (n < front) {
        float t = (n - (front - width)) / width;
        half3 gold = mix(half3(1.0, 0.95, 0.75), half3(0.85, 0.6, 0.25), half(t));
        half glow = half(1.0 - t);
        return half4(mix(c.rgb, gold * c.a, glow), c.a);
    }
    return c;
}

// MARK: - Scan line (colorEffect on a clear fill over the photo)

[[stitchable]] half4 scanLine(float2 position, half4 color, float2 size, float progress) {
    float y = position.y / max(size.y, 1.0);
    float d = abs(y - progress);
    float line = smoothstep(0.012, 0.0, d);
    float trail = smoothstep(0.18, 0.0, progress - y) * step(y, progress) * 0.18;
    float a = line * 0.9 + trail;
    half3 gold = half3(0.95, 0.82, 0.55);
    return half4(gold * half(a), half(a));
}
