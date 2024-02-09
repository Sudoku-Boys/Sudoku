#version 450

#include "camera.glsl"
#include "pbr_light.glsl"
#include "pbr.glsl"

layout(location = 0) in vec3 v_position;
layout(location = 1) in vec3 v_normal;
layout(location = 2) in vec4 v_tex_coord;

layout(location = 0) out vec4 o_color;

layout(set = 0, binding = 0) uniform StandardMaterial {
    vec4 base_color;
    float metallic;
    float roughness;
    float reflectance;

    vec4 emissive;

    float clearcoat;
    float clearcoat_roughness;

    float thickness;

    float index_of_refraction;
    vec4 absorption;

    vec4 subsurface_color;
    float subsurface_power;
} standard_material;

void main() {
    PbrMaterial material = default_pbr_material(
        gl_FragCoord,
        v_position,
        v_normal,
        camera.eye - v_position
    );

    material.albedo = standard_material.base_color.rgb;
    material.metallic = standard_material.metallic;
    material.roughness = standard_material.roughness;
    material.reflectance = standard_material.reflectance;

    material.emissive = standard_material.emissive.rgb;

    material.clearcoat = standard_material.clearcoat;
    material.clearcoat_roughness = standard_material.clearcoat_roughness;

    material.thickness = standard_material.thickness;

    material.index_of_refraction = standard_material.index_of_refraction;
    material.absorption = standard_material.absorption.rgb;

    material.subsurface_color = standard_material.subsurface_color.rgb;
    material.subsurface_power = standard_material.subsurface_power;

    PbrPixel pixel = compute_pbr_pixel(material);

    DirectionalLight light;
    light.direction = normalize(vec3(1.0, -1.0, -1.0));
    light.color = vec3(1.0, 1.0, 1.0);
    light.intensity = 1.0;
    
    vec3 color = pbr_light_directional(pixel, light);
    o_color = vec4(color, 1.0);
}
