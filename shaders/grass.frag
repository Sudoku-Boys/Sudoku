#version 450

#include "camera.glsl"

layout(location = 0) in vec3 v_position;
layout(location = 1) in float v_stiffness;

layout(location = 0) out vec4 o_color;

layout(set = 0, binding = 0) uniform GrassMaterial {
    float time;
} grass_material;

layout(set = 0, binding = 1) uniform sampler2D tex;

void main() {
    vec3 top_color = vec3(99.0 / 255.0, 252.0 / 255.0, 180.0 / 255.0);
    vec3 bottom_color = vec3(63.0 / 255.0, 180.0 / 255.0, 62.0 / 255.0);
    vec3 ao_color = vec3(27.0 / 255.0, 73.0 / 255.0, 15.0 / 255.0);

    vec3 color = mix(top_color, bottom_color, max(v_stiffness + 0.2, 0.0));
    color = mix(color, ao_color, max(v_stiffness - 0.7, 0.0) / 0.3);

    o_color = vec4(color, 1.0);
}
