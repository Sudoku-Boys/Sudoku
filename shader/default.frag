#version 450

#include "camera.glsl"
#include "pbr_light.glsl"
#include "pbr.glsl"

layout(location = 0) in vec3 v_position;
layout(location = 1) in vec3 v_normal;
layout(location = 2) in vec4 v_color;

layout(location = 0) out vec4 o_color;

void main() {
    PbrMaterial material = default_pbr_material(
        gl_FragCoord,
        v_position,
        v_normal,
        v_position - camera.eye
    );

    material.albedo = v_color.rgb;

    PbrPixel pixel = compute_pbr_pixel(material);

    DirectionalLight light;
    light.direction = normalize(vec3(1.0, 1.0, -1.0));
    light.color = vec3(1.0, 1.0, 1.0);
    light.intensity = 1.0;
    
    vec3 color = pixel.albedo * vec3(1.0, 0.9, 0.7) * vec3(0.1) + pbr_light_directional(pixel, light) * vec3(0.9);
    o_color = vec4(color, 1.0);
}
