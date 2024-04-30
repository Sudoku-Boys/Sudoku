#version 450

#include "fullscreen.glsl"
#include "dither.glsl"

layout(location = 0) out vec4 out_color;

layout(binding = 0) uniform sampler2D hdr_image;

vec3 tonemap_aces(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec3 color = texture(hdr_image, uv).rgb;

    color = tonemap_aces(color);

    // apply dithering to help with color banding
    //
    // https://shader-tutorial.dev/advanced/color-banding-dithering/
    color += dither(uv);

    out_color = vec4(color, 1.0);
    //out_color = vec4(1.0, 0.0, 1.0, 1.0);
}
