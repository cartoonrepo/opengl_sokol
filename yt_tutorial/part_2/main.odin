package main

import "core:fmt"
import "core:log"
import "base:runtime"

import stbi "vendor:stb/image"

import sapp  "sokol:app"
import sg    "sokol:gfx"
import sglue "sokol:glue"
import slog  "sokol:log"

default_context: runtime.Context

Vec2 :: [2]f32

Vertex_Data :: struct {
    position : Vec2,
    uv       : Vec2,
    color    : sg.Color,
}

State :: struct {
    shader        : sg.Shader,
    pipeline      : sg.Pipeline,
    bindings      : sg.Bindings,
    pass_action   : sg.Pass_Action,
    image         : sg.Image,
}

state: ^State

main :: proc() {
    context.logger = log.create_console_logger()
    default_context = context

    sapp.run({
        init_cb      = init,
        frame_cb     = frame,
        cleanup_cb   = cleanup,
        event_cb     = event,
        width        = 800,
        height       = 800,
        window_title = "Part_2: Textured Quad",
        icon         = { sokol_default = true },
        logger       = { func = slog.func },
    })
}

init :: proc "c" () {
    context = default_context

    sg.setup({
        environment = sglue.environment(),
        logger      = { func = slog.func },
    })

    state = new(State)

    // shader
    state.shader = sg.make_shader(main_shader_desc(sg.query_backend()))

    // pipeline
    state.pipeline = sg.make_pipeline({
        shader = state.shader,
        layout = {
            attrs = {
                ATTR_main_position = { format = .FLOAT2 },
                ATTR_main_uv       = { format = .FLOAT2 },
                ATTR_main_color    = { format = .FLOAT4 },
            },
        },
        index_type = .UINT16,
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
    })

    // vertex buffer
    vertices := []Vertex_Data {
        { position = { -0.5,  0.5 }, uv = { 0, 1 }, color = { 1.0, 1.0, 1.0, 1.0 } }, // top left
        { position = {  0.5,  0.5 }, uv = { 1, 1 }, color = { 1.0, 1.0, 1.0, 1.0 } }, // top right
        { position = {  0.5, -0.5 }, uv = { 1, 0 }, color = { 1.0, 1.0, 1.0, 1.0 } }, // bottom right
        { position = { -0.5, -0.5 }, uv = { 0, 0 }, color = { 1.0, 1.0, 1.0, 1.0 } }, // bottom left
    }

    state.bindings.vertex_buffers[0] = sg.make_buffer({
        data  = sg_range(vertices),
    })

    // index buffer
    indices := []u16 { 0, 1, 2, 2, 3, 0 }

    state.bindings.index_buffer = sg.make_buffer({
        usage =  { index_buffer = true },
        data  = sg_range(indices),
    })

    // image
    w, h: i32
    stbi.set_flip_vertically_on_load(true)
    pixels := stbi.load("assets/awesomeface.png", &w, &h, nil, 4)
    // pixels := stbi.load("assets/texture_13.png", &w, &h, nil, 4)
    assert(pixels != nil)

    state.image = sg.make_image({
        width          = w,
        height         = h,
        pixel_format   = .RGBA8,
        data           = {
            mip_levels = {
                0 = { ptr = pixels, size = uint(w * h * 4) },
            },
        },
    })

    state.bindings.views[VIEW_tex] = sg.make_view({
        texture = {
            image = state.image,
        },
    })

    stbi.image_free(pixels)

    // sampler
    state.bindings.samplers[SMP_smp] = sg.make_sampler({})

    // pass action
    state.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, store_action = .DEFAULT, clear_value = { 0.2, 0.4, 0.8, 1.0 } },
        },
    }
}

frame :: proc "c" () {
    context = default_context

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })

    sg.apply_pipeline(state.pipeline)
    sg.apply_bindings(state.bindings)

    sg.draw(0, 6, 1)

    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = default_context

    sg.destroy_buffer(state.bindings.vertex_buffers[0])
    sg.destroy_buffer(state.bindings.index_buffer)

    sg.destroy_image(state.image)

    sg.destroy_sampler(state.bindings.samplers[SMP_smp])
    sg.destroy_pipeline(state.pipeline)

    sg.destroy_view(state.bindings.views[VIEW_tex])

    sg.destroy_shader(state.shader)

    free(state)
    sg.shutdown()
}

event :: proc "c" (e: ^sapp.Event) {
    context = default_context

    #partial switch e.type {
    case .KEY_DOWN:
        #partial switch e.key_code {
        case .ESCAPE:
            sapp.request_quit()
        }
    }
}

sg_range :: proc(s: []$T) -> sg.Range {
    return {
        ptr  = raw_data(s),
        size = len(s) * size_of(s[0]),
    }
}
