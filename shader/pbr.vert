#version 450

vec2 positions[3] = vec2[](
    vec2( 0.0, -0.5),
    vec2( 0.5,  0.5),
    vec2(-0.5,  0.5)
);

layout(location = 0) in vec3 in_color;

layout(location = 0) out vec3 v_color;

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    v_color = in_color;
}
