#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

inline half4 sampleClamped(SwiftUI::Layer layer, float2 position, float2 bounds) {
    float2 upperBound = max(bounds, float2(0.0));
    return layer.sample(clamp(position, float2(0.0), upperBound));
}

/// Stable pixel cells with a 45-degree traveling blur wave.
/// Used as a SwiftUI `.layerEffect` so each cell can average neighboring samples.
[[stitchable]] half4 pixelate(
    float2 position,
    SwiftUI::Layer layer,
    float time,
    float cellSize,
    float minBlurRadius,
    float maxBlurRadius,
    float waveLength,
    float2 bounds
) {
    float resolvedCellSize = max(cellSize, 1.0);
    float2 center = bounds * 0.5;
    float2 relative = position - center;
    float2 cellCenter = floor(relative / resolvedCellSize + 0.5) * resolvedCellSize + center;

    // Constant-phase lines run at 45 degrees; the phase offset makes them travel.
    const float pi2 = 6.28318530718;
    const float2 waveNormal = float2(0.70710678118, 0.70710678118);
    float wavePhase = (dot(cellCenter, waveNormal) / max(waveLength, 1.0) - time * 0.27) * pi2;
    float waveStrength = smoothstep(0.18, 1.0, 0.5 + 0.5 * sin(wavePhase));
    float radius = mix(minBlurRadius, maxBlurRadius, waveStrength);

    float diagonalRadius = radius * 0.70710678118;
    half4 color = sampleClamped(layer, cellCenter, bounds) * half(0.28);
    color += sampleClamped(layer, cellCenter + float2(radius, 0.0), bounds) * half(0.10);
    color += sampleClamped(layer, cellCenter + float2(-radius, 0.0), bounds) * half(0.10);
    color += sampleClamped(layer, cellCenter + float2(0.0, radius), bounds) * half(0.10);
    color += sampleClamped(layer, cellCenter + float2(0.0, -radius), bounds) * half(0.10);
    color += sampleClamped(layer, cellCenter + float2(diagonalRadius, diagonalRadius), bounds) * half(0.08);
    color += sampleClamped(layer, cellCenter + float2(-diagonalRadius, diagonalRadius), bounds) * half(0.08);
    color += sampleClamped(layer, cellCenter + float2(diagonalRadius, -diagonalRadius), bounds) * half(0.08);
    color += sampleClamped(layer, cellCenter + float2(-diagonalRadius, -diagonalRadius), bounds) * half(0.08);

    return color;
}
