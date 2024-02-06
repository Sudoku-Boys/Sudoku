#version 450

#include "pbr.glsl"

layout(location = 0) in vec3 v_normal;

layout(location = 0) out vec4 o_color;

void main() {
    float l = dot(v_normal, normalize(vec3(1.0, 1.0, 1.0))) * 0.8 + 0.2;

    o_color = vec4(vec3(l), 1.0);
}
