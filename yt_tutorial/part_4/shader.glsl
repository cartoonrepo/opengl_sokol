@header package main
@header import sg "sokol:gfx"

@ctype mat4 Mat4

@vs vs
in vec3 position;
in vec2 uv;
in vec4 color;

out vec2 v_uv;
out vec4 v_color;

layout(binding=0) uniform Vs_Params {
    mat4 mvp;
};

void main() {
    gl_Position = mvp * vec4(position, 1);
    v_color = color;
    v_uv    = uv;
}
@end

@fs fs
out vec4 frag_color;

in vec2 v_uv;
in vec4 v_color;

layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

void main() {
    frag_color = texture(sampler2D(tex, smp), v_uv) * v_color;
}
@end

@program main vs fs
