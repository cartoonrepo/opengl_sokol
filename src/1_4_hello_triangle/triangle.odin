package main

import "base:runtime"
import "core:fmt"

import slog  "sokol:log"
import sg    "sokol:gfx"
import sapp  "sokol:app"
import sglue "sokol:glue"


state: struct {
    pip         : sg.Pipeline,
    bind        : sg.Bindings,
    pass_action : sg.Pass_Action,
}

init :: proc "c" () {
    context = runtime.default_context()

    sg.setup({
        environment = sglue.environment(),
        logger = { func = slog.func },
    })

    vertices := [?]f32 {
        // positions      // colors
         0.0,  0.5, 0.0,  1.0, 0.0, 0.0, 1.0, // top
         0.5, -0.5, 0.0,  0.0, 1.0, 0.0, 1.0, // bottom right
        -0.5, -0.5, 0.0,  0.0, 0.0, 1.0, 1.0, // bottom left
    }

    state.bind.vertex_buffers[0] = sg.make_buffer({
        data  = { ptr = &vertices, size = size_of(vertices) },
        label = "triangle-vertices",
    })

    state.pip = sg.make_pipeline({
        shader = sg.make_shader(triangle_shader_desc(sg.query_backend())),
        layout = {
            attrs = {
                ATTR_triangle_position = { format = .FLOAT3 },
                ATTR_triangle_color0   = { format = .FLOAT4 },
            },
        },
    })

    state.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.0, 0.04, 0.08, 1.0 }},
        },
    }
}

frame :: proc "c" () {
    context = runtime.default_context()

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pip)
    sg.apply_bindings(state.bind)
    sg.draw(0, 3, 1)
    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = runtime.default_context()
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

main :: proc() {
    sapp.run({
        init_cb      = init,
        frame_cb     = frame,
        cleanup_cb   = cleanup,
        event_cb     = event,
        width        = 1280,
        height       = 720,
        window_title = "hello triangle",
        icon         = { sokol_default = true },
        logger       = { func = slog.func },
    })
}
