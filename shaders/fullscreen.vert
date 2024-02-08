#version 450

// full screen quad
vec2 vertices[6] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2(-1.0,  1.0),
    vec2(-1.0,  1.0),
    vec2( 1.0, -1.0),
    vec2( 1.0,  1.0)
);

vec2 uv[6] = vec2[](
    vec2(0.0, 1.0),
    vec2(1.0, 1.0),
    vec2(0.0, 0.0),
    vec2(0.0, 0.0),
    vec2(1.0, 1.0),
    vec2(1.0, 0.0)
);

layout(location = 0) out vec2 v_uv;
layout(location = 1) out vec4 v_clip;

void main() {
    v_clip = vec4(vertices[gl_VertexIndex], 0.0, 1.0);
    gl_Position = vec4(vertices[gl_VertexIndex], 0.0, 1.0);
    v_uv = uv[gl_VertexIndex];
}
