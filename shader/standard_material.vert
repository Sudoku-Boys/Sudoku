#version 450

#include "camera.glsl"

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;

layout(location = 0) out vec3 v_normal;

layout(set = 1, binding = 0) uniform UBO {
    mat4 model;
} ubo;

void main() {
    gl_Position = camera.proj * camera.view * ubo.model * vec4(in_position, 1.0);
    v_normal = (camera.view * ubo.model * vec4(in_normal, 0.0)).xyz;
}
