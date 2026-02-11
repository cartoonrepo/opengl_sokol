@header package main
@header import sg "sokol:gfx"

@vs vs
in vec3 position;
in vec4 color;

out vec4 v_color;

void main() {
    gl_Position = vec4(position, 1.0);
    v_color = color;
}
@end

@fs fs
out vec4 frag_color;

in vec4 v_color;

void main() {
    frag_color = v_color;
}
@end

@program shader vs fs
