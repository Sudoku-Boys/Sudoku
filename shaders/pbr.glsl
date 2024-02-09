#include "pbr_pixel.glsl"

struct PbrMaterial {
    /* Geometry */
    vec4 frag_coord;
    vec3 position;
    vec3 normal;
    vec3 view;

    /* Material */
    vec3 albedo;
    float metallic;
    float roughness;
    float reflectance;
    vec3 emissive;

    /* Clearcoat */
    float clearcoat;
    float clearcoat_roughness;
    vec3 clearcoat_normal;

    /* Transmission and Subsurface */
    float thickness;

    /* Transmission */
    float transmission;
    float index_of_refraction;
    vec3 absorption;

    /* Subsurface */
    float subsurface_power;
    vec3 subsurface_color;
};

PbrMaterial default_pbr_material(
    vec4 frag_coord,
    vec3 position,
    vec3 normal,
    vec3 view
) {
    PbrMaterial material;

    material.frag_coord = frag_coord;
    material.position = position;
    material.normal = normal;
    material.view = view;

    material.albedo = vec3(1.0);
    material.metallic = 0.01;
    material.roughness = 0.089;
    material.reflectance = 0.5;
    material.emissive = vec3(0.0);

    material.clearcoat = 0.0;
    material.clearcoat_roughness = 0.0;
    material.clearcoat_normal = normal;

    material.thickness = 1.0;

    material.transmission = 0.0;
    material.index_of_refraction = 1.5;
    material.absorption = vec3(0.0);

    material.subsurface_power = 0.0;
    material.subsurface_color = vec3(1.0);

    return material;
}

float linear_to_perceptual_roughness(float linear_roughness) {
    return sqrt(linear_roughness);
}

vec3 compute_f0(vec3 albedo, float metallic, float reflectance) {
    float a = 0.16 * reflectance * reflectance * (1.0 - metallic);
    vec3 b = albedo * metallic;
    return a + b;
}

float compute_f90(vec3 f0) {
    return clamp(dot(f0, vec3(50.0 * 0.33)), 0.0, 1.0);
}

vec3 compute_diffuse(vec3 albedo, float metallic) {
    return albedo * (1.0 - metallic);
}

PbrPixel compute_pbr_pixel(PbrMaterial material) {
    PbrPixel pixel;

    pixel.frag_coord = material.frag_coord;
    pixel.position = material.position;
    pixel.normal = normalize(material.normal);
    pixel.view = normalize(material.view);
    pixel.reflect = reflect(-pixel.view, pixel.normal);

    pixel.albedo = material.albedo;
    pixel.diffuse = compute_diffuse(material.albedo, material.metallic);
    pixel.perceptual_roughness = linear_to_perceptual_roughness(material.roughness);
    pixel.roughness = material.roughness;
    pixel.f0 = compute_f0(material.albedo, material.metallic, material.reflectance);
    pixel.f90 = compute_f90(pixel.f0);
    pixel.dfg = vec3(0.0);

    pixel.clearcoat = material.clearcoat;
    pixel.clearcoat_perceptual_roughness = linear_to_perceptual_roughness(material.clearcoat_roughness);
    pixel.clearcoat_roughness = material.clearcoat_roughness;
    pixel.clearcoat_normal = normalize(material.clearcoat_normal);
    pixel.clearcoat_reflect = reflect(-pixel.view, pixel.clearcoat_normal);

    pixel.thickness = material.thickness;

    pixel.transmission = material.transmission;
    pixel.absorption = material.absorption;

    float air_ior = 1.0;
    float ior = max(1.0, material.index_of_refraction);

    pixel.eta_ir = air_ior / ior;
    pixel.eta_ri = ior / air_ior;

    pixel.subsurface_power = material.subsurface_power;
    pixel.subsurface_color = material.subsurface_color;

    return pixel;
}
