package main

import "base:runtime"
import "core:log"

import stbi "vendor:stb/image"

import sg    "sokol:gfx"
import sapp  "sokol:app"
import sglue "sokol:glue"
import shelp "sokol:helpers"

Vec3 :: [3]f32
Vec2 :: [2]f32

Vertex_Data :: struct {
    position : Vec3,
    uv       : Vec2,
}

state: struct {
    shader      : sg.Shader,
    bind        : sg.Bindings,
    pipe        : sg.Pipeline,
    pass_action : sg.Pass_Action,
}

ctx: runtime.Context
main :: proc() {
    context.logger = log.create_console_logger()
    ctx = context

    sapp.run({
        init_cb      = init,
        frame_cb     = frame,
        cleanup_cb   = cleanup,
        event_cb     = event,
        width        = 1280,
        height       = 720,
        window_title = "multiple-textures",
        icon         = { sokol_default = true },
        logger       = sapp.Logger(shelp.logger(&ctx)),
    })
}

init :: proc "c" () {
    context = ctx

    sg.setup({
        logger      = sg.Logger(shelp.logger(&ctx)),
        environment = sglue.environment(),
    })

    // pass action
    state.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.0, 0.04, 0.08, 1.0 }}

    // shader
    state.shader = sg.make_shader(multiple_textures_shader_desc(sg.query_backend()))

    // setup pipeline
    state.pipe = sg.make_pipeline({
        shader     = state.shader,
        layout     = {
            attrs = {
                ATTR_multiple_textures_position  = { format = .FLOAT3 },
                ATTR_multiple_textures_tex_coord = { format = .FLOAT2 },
            },
        },

        colors = {
            0 = {
                blend = {
                    enabled          = true,
                    src_factor_rgb   = .SRC_ALPHA,
                    dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
                    src_factor_alpha = .ONE,
                    dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
                },
            },
        },

        index_type = .UINT16,
        label      = "triangle-pipeline",
    })

    // buffer bindings
    vertices := [?]Vertex_Data {
        { position = { -0.5,  0.5, 0.0 }, uv = { 0, 1 } }, // top left
        { position = {  0.5,  0.5, 0.0 }, uv = { 1, 1 } }, // top right
        { position = {  0.5, -0.5, 0.0 }, uv = { 1, 0 } }, // bottom right
        { position = { -0.5, -0.5, 0.0 }, uv = { 0, 0 } }, // bottom left
    }

    indices := [?]u16 { 0, 1, 2, 0, 2, 3 }

    state.bind.vertex_buffers[0] = sg.make_buffer({
        usage = { vertex_buffer = true },
        data  = { ptr = &vertices, size = size_of(vertices) },
        label = "triangle-vertices",
    })

    state.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = { ptr = &indices, size = size_of(indices) },
        label = "triangle-indices",
    })

    bind_view_texture("assets/container.jpg",   VIEW_f_texture1, SMP_f_texture1_sampler)
    bind_view_texture("assets/awesomeface.png", VIEW_f_texture2, SMP_f_texture2_sampler)

    interpolate.mix_value = 0.2
}

interpolate: F_Interpolate

frame :: proc "c" () {
    context = ctx

    if key_code[.ESCAPE] do sapp.request_quit()
    if key_code[.W] do interpolate.mix_value += 0.02
    if key_code[.S] do interpolate.mix_value -= 0.02

    interpolate.mix_value = clamp(interpolate.mix_value, 0, 1)

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pipe)
    sg.apply_bindings(state.bind)

    sg.apply_uniforms(UB_f_interpolate, { ptr = &interpolate, size = size_of(F_Interpolate) })

    sg.draw(0, 6, 1)

    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    sg.destroy_buffer(state.bind.vertex_buffers[0])
    sg.destroy_buffer(state.bind.index_buffer)

    sg.destroy_image(sg.Image(state.bind.views[VIEW_f_texture1]))
    sg.destroy_image(sg.Image(state.bind.views[VIEW_f_texture2]))

    sg.destroy_sampler(state.bind.samplers[SMP_f_texture1_sampler])
    sg.destroy_sampler(state.bind.samplers[SMP_f_texture2_sampler])

    sg.destroy_shader(state.shader)

    sg.destroy_pipeline(state.pipe)

    sg.destroy_view(state.bind.views[VIEW_f_texture1])
    sg.destroy_view(state.bind.views[VIEW_f_texture2])

    sg.shutdown()
}

key_code: #sparse[sapp.Keycode]bool
event :: proc "c" (e: ^sapp.Event) {
    context = ctx
    #partial switch e.type {
    case .KEY_DOWN : key_code[e.key_code] = true
    case .KEY_UP   : key_code[e.key_code] = false
    }
}

bind_view_texture :: proc(image_file: cstring, texture_index, sampler_index: i32) {
    stbi.set_flip_vertically_on_load(auto_cast true)

    w, h: i32
    pixels := stbi.load(image_file, &w, &h, nil, 4)
    defer stbi.image_free(pixels)

    assert(pixels != nil)

    image := sg.make_image({
        width        = w,
        height       = h,
        pixel_format = .RGBA8,
        data         = { mip_levels = { 0 = { ptr = pixels, size = uint(w * h * 4) } } },
    })

    state.bind.views[texture_index] = sg.make_view({
        texture = {
            image = image,
        },
    })

    state.bind.samplers[sampler_index] = sg.make_sampler({
        min_filter    = .LINEAR,
        mag_filter    = .LINEAR,
        mipmap_filter = .LINEAR,
        wrap_u        = .REPEAT,
        wrap_v        = .REPEAT,
    })
}
