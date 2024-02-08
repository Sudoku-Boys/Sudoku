struct DirectionalLight {
    vec3 direction;
    vec3 color;
    float intensity;
};

struct Light {
    vec3 direction;
    vec3 color;

    float intensity;
    float attenuation;
    float occlusion;
};
