#version 450

#include "fullscreen.glsl"

layout(location = 0) out vec4 out_color;

layout(binding = 0) uniform sampler2D hdr_image;

void main() {
    out_color = texture(hdr_image, uv);
}
