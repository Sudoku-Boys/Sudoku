#version 450

#include "pbr.glsl"
#include "camera.glsl"

layout(location = 0) in vec3 v_position;
layout(location = 1) in vec3 v_normal;
layout(location = 2) in vec3 v_tangent;
layout(location = 3) in vec3 v_bitangent;
layout(location = 4) in vec2 v_tex_coord;

layout(location = 0) out vec4 o_color;

layout(set = 0, binding = 0) uniform GrassMaterial {
    float time;
} grass_material;

layout(set = 0, binding = 1) uniform sampler2D tex;

void main() {
    PbrMaterial material = default_pbr_material(
        gl_FragCoord,
        v_position,
        v_normal,
        camera.eye - v_position
    );

    vec4 base_color = texture(tex, v_tex_coord);

    material.albedo = base_color.rgb;

    PbrPixel pixel = compute_pbr_pixel(material);

    DirectionalLight light;
    light.direction = normalize(vec3(1.0, -1.0, -1.0));
    light.color = vec3(1.0, 1.0, 1.0);
    light.intensity = 5.0;
    
    vec3 color = pbr_light_directional(pixel, light);
    color += pbr_refraction(pixel, vec3(0.5));
    color += material.emissive;

    vec3 sky_diffuse = max(dot(pixel.normal, vec3(0.0, 1.0, 0.0)), 0.4) * vec3(0.8, 0.9, 1.0);
    color += pixel.albedo * sky_diffuse * 0.8;

    vec3 bounce_diffuse = max(dot(pixel.normal, vec3(0.0, -1.0, 0.0)), 0.0) * vec3(1.0, 0.7, 0.6);
    color += pixel.albedo * bounce_diffuse * 0.1;

    o_color = vec4(color, 1.0);
}
