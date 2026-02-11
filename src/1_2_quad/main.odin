package main

import "core:log"

import "base:runtime"

import slog  "sokol:log"
import sg    "sokol:gfx"
import sapp  "sokol:app"
import sglue "sokol:glue"
import shelp "sokol:helpers"

key_code: #sparse[sapp.Keycode]bool

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

// NOTE:
// either change IS_WIRE_FRAME value to true/false here or
// add -define:IS_WIRE_FRAME=true/false to compiler.
IS_WIRE_FRAME :: #config(IS_WIRE_FRAME, true)

Vertex_Buffer :: struct {
    position : Vec3,
    color    : Vec4,
}

indices: []u32

state: struct {
    shader      : sg.Shader,
    pipe        : sg.Pipeline,
    bind        : sg.Bindings,
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
        window_title = "Quad",
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

    // shader
    state.shader = sg.make_shader(quad_shader_desc(sg.query_backend()))

    // pipeline
    state.pipe = sg.make_pipeline({
        shader = state.shader,

        layout = {
            attrs = {
                ATTR_quad_position = { format = .FLOAT3 },
                ATTR_quad_color    = { format = .FLOAT4 },
            },
        },

        primitive_type = IS_WIRE_FRAME ? .LINES : .TRIANGLES,
        index_type     = .UINT32,
        label          = "quad_pipeline",
    })


    // vertex buffer
    vertices := [?]Vertex_Buffer {
        { position = { -0.5,  0.5,  0.0 }, color = { 1.0,  0.0,  0.0,  1.0 } }, // top    left
        { position = {  0.5,  0.5,  0.0 }, color = { 0.0,  1.0,  0.0,  1.0 } }, // top    right
        { position = {  0.5, -0.5,  0.0 }, color = { 0.0,  1.0,  1.0,  1.0 } }, // bottom right
        { position = { -0.5, -0.5,  0.0 }, color = { 0.0,  0.0,  1.0,  1.0 } }, // bottom left
    }

    quad_indices := [?]u32 { 0, 1, 2, 0, 2, 3 }

    wire_indices := [?]u32 {
        0, 1,
        1, 2,
        2, 0,
        2, 3,
        3, 0,
    }

    indices = IS_WIRE_FRAME ? wire_indices[:] : quad_indices[:]

    state.bind.vertex_buffers[0] = sg.make_buffer({
        usage = { vertex_buffer = true },
        data  = { ptr = &vertices, size = size_of(vertices) },
        label = "quad_vertices",
    })

    state.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = { ptr = raw_data(indices), size = len(indices) * size_of(indices[0]) },
        label = "quad_indices",
    })

    // pass action
    state.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.0, 0.04, 0.08, 1.0 }},
        },
    }
}

frame :: proc "c" () {
    context = ctx

    if key_code[.ESCAPE] do sapp.request_quit()

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pipe)
    sg.apply_bindings(state.bind)
    sg.draw(0, len(indices), 1)

    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = ctx

    sg.destroy_buffer(state.bind.vertex_buffers[0])
    sg.destroy_buffer(state.bind.index_buffer)
    sg.destroy_shader(state.shader)
    sg.destroy_pipeline(state.pipe)

    sg.shutdown()
}

event :: proc "c" (e: ^sapp.Event) {
    #partial switch e.type {
    case .KEY_DOWN : key_code[e.key_code] = true
    case .KEY_UP   : key_code[e.key_code] = false
    }
}
