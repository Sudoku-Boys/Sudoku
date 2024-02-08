#version 450

#include "camera.glsl"
#include "fullscreen.glsl"

layout(location = 0) out vec4 out_color;

void main() {
    vec4 near = camera.inv_view_proj * vec4(clip.xy, 0.0, 1.0);
    vec4 far = camera.inv_view_proj * vec4(clip.xy, 1.0, 1.0);
    near /= near.w;
    far /= far.w;

    vec3 view = normalize(far.xyz - near.xyz);

    vec3 color = mix(vec3(0.4, 0.5, 0.6), vec3(0.4, 0.5, 0.9), max(view.y, 0.0));

    out_color = vec4(color, 1.0);
}
