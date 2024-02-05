#version 450

#include "pbr.glsl"

layout(location = 0) in vec3 i_color;

layout(location = 0) out vec4 o_color;

layout(binding = 1) uniform sampler2D texSampler;

void main() {
    o_color = vec4(texture(texSampler, i_color.xy).xyz, 1.0);
}
