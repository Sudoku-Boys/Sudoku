#include "random.glsl"

const float NOISE_GRAIN = 1.0 / 255.0;

// Dithering function
//
// https://shader-tutorial.dev/advanced/color-banding-dithering/
float dither(vec2 uv) {
    float noise = random(uv);
    return (noise - 0.5) * NOISE_GRAIN;
}
