#include <metal_stdlib>
using namespace metal;

/// Pixelation distortion — snaps each sample position to the nearest cell center,
/// with the grid anchored at `center` so blocks expand symmetrically.
/// Used as a SwiftUI `.distortionEffect`.
[[stitchable]] float2 pixelate(float2 position, float cellSize, float2 center) {
    float2 relative = position - center;
    float2 snapped = floor(relative / cellSize + 0.5) * cellSize;
    return snapped + center;
}
