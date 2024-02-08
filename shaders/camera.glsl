layout(set = 2, binding = 0) uniform Camera {
    mat4 view;
    mat4 proj;
    mat4 view_proj;
    mat4 inv_view_proj;
    vec3 eye;
} camera;
