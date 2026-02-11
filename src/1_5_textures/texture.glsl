@header package main
@header import sg "sokol:gfx"

@vs vs
in vec3 position;
in vec2 tex_coord;
in vec4 color;

out vec2 v_tex_coord;
out vec4 v_color;

void main() {
    gl_Position = vec4(position, 1.0);
    v_tex_coord = tex_coord;
    v_color     = color;
}
@end

@fs fs
out vec4 frag_color;

in vec2 v_tex_coord;
in vec4 v_color;

layout(binding=0) uniform texture2D f_texture;
layout(binding=0) uniform sampler   f_sampler;

#define txt sampler2D(f_texture, f_sampler)

void main() {
    frag_color = texture(txt, v_tex_coord) * v_color;
}
@end

@program textures vs fs
