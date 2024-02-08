#version 450

#include "camera.glsl"
#include "model.glsl"

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in uint in_color;

layout(location = 0) out vec3 v_position;
layout(location = 1) out vec3 v_normal;
layout(location = 2) out vec4 v_color;

void main() {
    vec4 position = model * vec4(in_position, 1.0);

    gl_Position = camera.view_proj * position;
    v_position = position.xyz;

    vec4 normal = model * vec4(in_normal, 0.0); 
    v_normal = normal.xyz;

    v_color = unpackUnorm4x8(in_color);
}
