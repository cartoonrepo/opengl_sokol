package main

import "core:log"

import "base:runtime"

import sapp  "sokol:app"
import sg    "sokol:gfx"
import slog  "sokol:log"
import sglue "sokol:glue"
import shelp "sokol:helpers"

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

BG_COLOR :: sg.Color { 0.0, 0.04, 0.08, 1.0 }
RED      :: sg.Color { 1.0, 0.0, 0.0, 1.0 }
GREEN    :: sg.Color { 0.0, 1.0, 0.0, 1.0 }
BLUE     :: sg.Color { 0.0, 0.0, 1.0, 1.0 }

Vertex_Data :: struct {
    position : Vec3,
    color    : sg.Color,
}

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
        window_title = "Shaders",
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

    switch sg.query_backend() {
    case .D3D11:                                     log.info(">> using D3D11 backend")
    case .GLCORE, .GLES3:                            log.info(">> using GL backend")
    case .METAL_MACOS, .METAL_IOS, .METAL_SIMULATOR: log.info(">> using Metal backend")
    case .WGPU:                                      log.info(">> using WebGPU backend")
    case .VULKAN:                                    log.info(">> using Vulkan backend")
    case .DUMMY:                                     log.info(">> using dummy backend")
    }

    // pass action
    state.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = BG_COLOR },
        },
    }

    // create shader
    state.shader = sg.make_shader(shader_shader_desc(sg.query_backend()))

    // bind buffers
    vertices := [?]Vertex_Data {
        { position = {  0.0,  0.5, 0.0 }, color = RED   }, // top
        { position = {  0.5, -0.5, 0.0 }, color = GREEN }, // bottom right
        { position = { -0.5, -0.5, 0.0 }, color = BLUE  }, // botoom left
    }

    state.bind.vertex_buffers[0] = sg.make_buffer({
        usage = { vertex_buffer = true },
        data  = { ptr = &vertices, size = size_of(vertices) },
        label = "triangle_vertices",
    })

    // create pipeline
    state.pipe = sg.make_pipeline({
        shader = state.shader,

        layout = {
            attrs = {
                ATTR_shader_position = { format = .FLOAT3 },
                ATTR_shader_color    = { format = .FLOAT4 },
            },
        },

        label = "triangle_pipeline",
    })
}

frame :: proc "c" () {
    context = ctx

    if key_code[.ESCAPE] do sapp.request_quit()

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pipe)
    sg.apply_bindings(state.bind)
    sg.draw(0, 3, 1)
    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = ctx

    sg.destroy_buffer(state.bind.vertex_buffers[0])
    sg.destroy_shader(state.shader)
    sg.destroy_pipeline(state.pipe)

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
