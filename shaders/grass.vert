#version 450

#include "camera.glsl"
#include "model.glsl"
#include "random.glsl"
#include "noise.glsl"

layout(location = 0) in vec3 in_position;
layout(location = 1) in float in_stiffness;

layout(location = 0) out vec3 v_position;
layout(location = 1) out float v_stiffness;

layout(set = 0, binding = 0) uniform GrassMaterial {
    float time;
} grass_material;

const float PI = 3.14159265359;

void main() { 
    vec4 position = model * vec4(in_position, 1.0);

    float noise = noise(position.xz * 10.0) 
      + random(position.xz * 20.0) * 0.5;

    float sway_factor = pow(1.0 - in_stiffness, 1.6);

    vec3 sway = vec3(
        sin(grass_material.time * 2.5
        + position.x * 0.1 
        + position.z * 0.1
        + noise) * 0.2 * sway_factor,
        0.0,
        cos(grass_material.time * 2.5
        + position.x * 0.1
        + position.z * 0.1
        + noise) * 0.2 * sway_factor
    );

    position.xyz += sway;

    gl_Position = camera.view_proj * position;
    v_position = position.xyz;

    v_stiffness = in_stiffness;
}
