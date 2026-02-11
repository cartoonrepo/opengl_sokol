@header package main
@header import sg "sokol:gfx"

@vs vs
in vec3 position;

void main() {
    gl_Position = vec4(position, 1.0);
}
@end

@fs fs
out vec4 frag_color;

layout(binding = 0) uniform fs_params {
    vec4 our_color;
};

void main() {
    frag_color = our_color;
}
@end

@program uniforms vs fs
