#version 450

#include "camera.glsl"
#include "model.glsl"

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_text_coord;

layout(location = 0) out vec3 v_position;
layout(location = 1) out vec3 v_normal;
layout(location = 2) out vec2 v_tex_coord;

void main() {
    vec4 position = model * vec4(in_position, 1.0);

    gl_Position = camera.view_proj * position;
    v_position = position.xyz;

    vec4 normal = model * vec4(in_normal, 0.0); 
    v_normal = normal.xyz;

    v_tex_coord = in_text_coord;
}
