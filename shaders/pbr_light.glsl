#include "light.glsl"
#include "transmission.glsl"
#include "camera.glsl"
#include "pbr_pixel.glsl"

const float PI = 3.1415926535897932384626433832795;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float get_distance_attenuation(float distance_squared, float inverse_range_squared) {
    float factor = distance_squared * inverse_range_squared;
    float smooth_factor = saturate(1.0 - factor * factor);
    float attenuation = smooth_factor * smooth_factor;
    return attenuation / max(0.0001, distance_squared);
}

float fd_lambert() {
    return 1.0 / PI;
}

float d_ggx(float roughness, float noh) {
    float o = 1.0 - noh * noh;
    float a = noh * roughness;
    float k = roughness / (o + a * a);
    float d = k * k * fd_lambert();
    return d;
}

float v_smith(float roughness, float nov, float nol) {
    float a2 = roughness * roughness;
    float lambda_v = nol * sqrt((nov - a2 * nov) * nov + a2);
    float lambda_l = nov * sqrt((nol - a2 * nol) * nol + a2);
    return 0.5 / (lambda_v + lambda_l);
}

float v_kelemen(float loh) {
    return 0.25 / (loh * loh);
}

float f_schlick(float f0, float f90, float voh) {
    return f0 + (f90 - f0) * pow(1.0 - voh, 5.0);
}

vec3 f_schlick(vec3 f0, float f90, float voh) {
    return f0 + (f90 - f0) * pow(1.0 - voh, 5.0);
}

vec3 fresnel(vec3 f0, float loh) {
    float f90 = saturate(dot(f0, vec3(50.0 * 0.33)));
    return f_schlick(f0, f90, loh);
}

vec3 pbr_specular_lobe(
    float roughness,
    vec3 f0,
    float nov,
    float nol,
    float noh,
    float loh
) {
    float d = d_ggx(roughness, noh);
    float v = v_smith(roughness, nov, nol);
    vec3 f = fresnel(f0, loh);

    return d * v * f;
}

struct ClearcoatResult {
    float specular;
    float fresnel;
};

ClearcoatResult pbr_clearcoat_lobe(
    float roughness,
    float clearcoat,
    float noh,
    float loh
) {
    float d = d_ggx(roughness, noh);
    float v = v_kelemen(loh);
    float f = f_schlick(0.04, 1.0, loh) * clearcoat;
    float specular = d * v * f;

    return ClearcoatResult(specular, f);
}

float fd_burley(float roughness, float nov, float nol, float loh) {
    float f90 = 0.5 + 2.0 * roughness * loh * loh;
    float light_scatter = f_schlick(1.0, f90, loh);
    float view_scatter = f_schlick(1.0, f90, loh);
    return light_scatter * view_scatter * fd_lambert();
}

vec3 pbr_light_surface(PbrPixel pixel, Light light) {
    vec3 h = normalize(light.direction + pixel.view);
    float nol = saturate(dot(pixel.normal, light.direction));
    float noh = saturate(dot(pixel.normal, h));
    float loh = saturate(dot(light.direction, h));
    float nov = saturate(dot(pixel.normal, pixel.view));

    if (nol < 0.0 || noh < 0.0) {
        return vec3(0.0);
    }

    vec3 diffuse_light = fd_burley(pixel.roughness, nov, nol, loh) * pixel.diffuse;
    vec3 specular_light = pbr_specular_lobe(pixel.roughness, pixel.f0, nov, nol, noh, loh);

    /* transmission */
    diffuse_light *= 1.0 - pixel.transmission;

    vec3 color = (diffuse_light + specular_light) * nol;

    if (pixel.clearcoat > 0.0) {
        float clearcoat_nol = saturate(dot(pixel.clearcoat_normal, light.direction));
        float clearcoat_noh = saturate(dot(pixel.clearcoat_normal, h));

        ClearcoatResult ccr = pbr_clearcoat_lobe(pixel.clearcoat_roughness, pixel.clearcoat, clearcoat_noh, loh);
        float attenuation = 1.0 - ccr.fresnel;

        diffuse_light *= attenuation;
        specular_light *= attenuation;

        color += ccr.specular * clearcoat_nol;
    }

    color *= light.occlusion;

    if (pixel.subsurface_power > 0.0) {
        float scatter_voh = saturate(dot(pixel.view, -light.direction));
        float forward_scatter = exp2(scatter_voh * pixel.subsurface_power - pixel.subsurface_power);
        float back_scatter = saturate(nol * pixel.thickness + (1.0 - pixel.thickness)) * 0.5;
        float subsurface = mix(back_scatter, 1.0, forward_scatter) * (1.0 - pixel.thickness);
        color += pixel.subsurface_color * subsurface * fd_lambert();
    }

    color *= light.color * light.intensity * light.attenuation;

    return color;
}

vec3 pbr_light_directional(
    PbrPixel pixel,
    DirectionalLight directional
) {
    Light light;

    light.color = directional.color;
    light.direction = -directional.direction;

    light.intensity = directional.intensity;
    light.attenuation = 1.0;
    light.occlusion = 1.0;

    return pbr_light_surface(pixel, light);
}

struct PbrRefractionRay {
    vec3 position;
    vec3 direction;
    float distance;
};

PbrRefractionRay pbr_refract_solid_sphere(PbrPixel pixel) {
    PbrRefractionRay ray;

    vec3 r = refract(-pixel.view, pixel.normal, pixel.eta_ir);    
    float nor = dot(pixel.normal, r);
    float d = pixel.thickness * -nor;
    ray.position = pixel.position + r * d;
    ray.distance = d;

    vec3 n = normalize(nor * r - pixel.normal * 0.5);
    ray.direction = refract(r, n, pixel.eta_ri);

    return ray;
}

vec3 pbr_refraction(PbrPixel pixel, vec3 e) {
    if (pixel.transmission == 0.0) return vec3(0.0);

    PbrRefractionRay ray = pbr_refract_solid_sphere(pixel);
    vec3 t = min(vec3(1.0), exp(-pixel.absorption * ray.distance));

    float s = saturate(pixel.eta_ir * 3.0 - 2.0);
    float perceptual_roughness = mix(pixel.perceptual_roughness, 0.0, s);

    vec4 position = camera.view_proj * vec4(ray.position, 1.0);
    vec2 uv = position.xy / position.w * 0.5 + 0.5;

    float levels = textureQueryLevels(transmission_sampler);
    float lod = perceptual_roughness * perceptual_roughness * levels;
    vec3 color = textureLod(transmission_sampler, uv, lod).rgb;

    color *= pixel.diffuse;
    color *= 1.0 - e;
    color *= t;

    return color * pixel.transmission;
}

vec3 pbr_light(PbrPixel pixel) {
    return vec3(1.0);
}
