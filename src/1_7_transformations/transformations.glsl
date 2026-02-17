@header package main
@header import sg "sokol:gfx"

@ctype mat4 Mat4

@vs vs
in vec3 position;
in vec2 tex_coord;

layout(binding = 0) uniform vs_params {
    mat4 mvp;
};

out vec2 v_tex_coord;
void main() {
    gl_Position = mvp * vec4(position, 1.0);
    v_tex_coord = tex_coord;
}
@end

@fs fs
out vec4 frag_color;

in vec2 v_tex_coord;

layout(binding=0) uniform texture2D f_texture1;
layout(binding=0) uniform sampler   f_texture1_sampler;

layout(binding=1) uniform texture2D f_texture2;
layout(binding=1) uniform sampler   f_texture2_sampler;

layout(binding = 2) uniform fs_params {
    float mix_value;
};

#define tx1 sampler2D(f_texture1, f_texture1_sampler)
#define tx2 sampler2D(f_texture2, f_texture2_sampler)

void main() {
    frag_color = mix(texture(tx1, v_tex_coord), texture(tx2, v_tex_coord), mix_value);
}
@end

@program transformations vs fs
