package main

import "core:fmt"
import "core:log"
import "base:runtime"

import sapp  "sokol:app"
import sg    "sokol:gfx"
import sglue "sokol:glue"
import slog "sokol:log"
import shelp "sokol:helpers"

Vec2 :: [2]f32

Vertex_Data :: struct {
    position : Vec2,
    color    : sg.Color,
}

State :: struct {
    shader        : sg.Shader,
    pipeline      : sg.Pipeline,
    bindings      : sg.Bindings,
    pass_action   : sg.Pass_Action,
}

state: ^State

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
        window_title = "Part_1: Triangle",
        icon         = { sokol_default = true },
        logger       = transmute(sapp.Logger)shelp.logger(&ctx), // app logger
    })
}

init :: proc "c" () {
    context = ctx

    sg.setup({
        environment = sglue.environment(),
        logger      = transmute(sg.Logger)shelp.logger(&ctx), // gfx logger
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
                ATTR_main_color    = { format = .FLOAT4 },
            },
        },
    })

    // vertex buffer
    vertices := []Vertex_Data {
        // positions //color
        { position = {  0.0,  0.5 }, color = { 1.0, 0.0, 0.0, 1.0 } },
        { position = {  0.5, -0.5 }, color = { 0.0, 1.0, 0.0, 1.0 } },
        { position = { -0.5, -0.5 }, color = { 0.0, 0.0, 1.0, 1.0 } },
    }

    state.bindings.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = raw_data(vertices), size = len(vertices) * size_of(vertices[0]) },
    })

    // pass action
    state.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, store_action = .DEFAULT, clear_value = { 0.0, 0.04, 0.08, 1.0 } },
        },
    }
}

frame :: proc "c" () {
    context = ctx
    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })

    sg.apply_pipeline(state.pipeline)
    sg.apply_bindings(state.bindings)

    sg.draw(0, 3, 1)

    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = ctx
    sg.destroy_buffer(state.bindings.vertex_buffers[0])
    sg.destroy_pipeline(state.pipeline)
    sg.destroy_shader(state.shader)

    free(state)
    sg.shutdown()
}

event :: proc "c" (e: ^sapp.Event) {
    #partial switch e.type {
    case .KEY_DOWN:
        #partial switch e.key_code {
        case .ESCAPE:
            sapp.request_quit()
        }
    }
}
