struct PbrPixel {
    /* Geometry */
    vec4 frag_coord;
    vec3 position;
    vec3 view;
    vec3 normal;
    vec3 reflect;

    /* Material */
    vec3 albedo;
    vec3 diffuse;
    float perceptual_roughness;
    float roughness;
    vec3 f0;
    float f90;
    vec3 dfg;

    /* Clearcoat */
    float clearcoat;
    float clearcoat_perceptual_roughness;
    float clearcoat_roughness;
    vec3 clearcoat_normal;
    vec3 clearcoat_reflect;

    /* Transmission and Subsurface */
    float thickness;

    /* Transmission */
    float transmission;
    float eta_ir;
    float eta_ri;
    vec3 absorption;

    /* Subsurface */
    float subsurface_power;
    vec3 subsurface_color;
};
