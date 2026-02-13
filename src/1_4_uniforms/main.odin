package main

import "base:runtime"
import "base:intrinsics"
import "core:math"
import "core:log"
import "core:time"

import sapp  "sokol:app"
import sg    "sokol:gfx"
import sglue "sokol:glue"
import shelp "sokol:helpers"

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

state: struct {
    shader      : sg.Shader,
    pipe        : sg.Pipeline,
    bind        : sg.Bindings,
    pass_action : sg.Pass_Action,
}

MAX_DELTATIME :: 1.0 / 20.0

current_time  : time.Tick
previous_time : time.Tick
accumulator   : f32

ctx: runtime.Context
main :: proc() {
    context.logger = log.create_console_logger()
    ctx = context

    previous_time = time.tick_now()

    sapp.run({
    init_cb      = init,
    frame_cb     = frame,
    cleanup_cb   = cleanup,
    event_cb     = event,
    width        = 1280,
    height       = 720,
    window_title = "uniforms",
    icon         = { sokol_default = true },
    logger       = sapp.Logger(shelp.logger(&ctx)), // app logger
    })
}

init :: proc "c" () {
    context = ctx

    // setup
    sg.setup({
        logger      = sg.Logger(shelp.logger(&ctx)),
        environment = sglue.environment(),
    })

    switch sg.query_backend() {
    case .D3D11:                                     log.info(">> using D3D11 backend")
    case .GLCORE, .GLES3:                            log.info(">> using GL backend")
    case .METAL_MACOS, .METAL_IOS, .METAL_SIMULATOR: log.info(">> using Metal backend")
    case .WGPU:                                      log.info(">> using WebGPU backend")
    case .VULKAN:                                    log.info(">> using Vulkan backend")
    case .DUMMY:                                     log.info(">> using dummy backend")
    }

    // shader
    state.shader = sg.make_shader(uniforms_shader_desc(sg.query_backend()))

    // bind buffers
    vertices := [?]f32 {
        0.0,  0.5, 0.0, // top
        0.5, -0.5, 0.0, // bottom right
       -0.5, -0.5, 0.0, // bottom left
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
                ATTR_uniforms_position = { format = .FLOAT3 },
            },
        },
        label  = "triangle_pipeline",
    })

    // pass action
    state.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.0, 0.04, 0.08, 1.0 }}
}

frame :: proc "c" () {
    context = ctx

    current_time = time.tick_now()
    dt := clamp(f32(time.duration_seconds(time.tick_diff(previous_time, current_time))), 0, MAX_DELTATIME)
    previous_time = current_time

    accumulator += dt

    red   := clamp(math.sin_f32(accumulator), 0.2, 1)
    green := clamp(math.cos_f32(accumulator), 0.2, 1)
    blue  := clamp(math.sin_f32(red + green), 0.2, 1)

    fs_params := Fs_Params {
        our_color = { red, green, blue, 1.0 }, // uniform from shader
    }

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pipe)
    sg.apply_bindings(state.bind)

    sg.apply_uniforms(UB_fs_params, { ptr = &fs_params, size = size_of(Fs_Params) })

    sg.draw(0, 3, 1)
    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = ctx

    sg.destroy_shader(state.shader)
    sg.destroy_buffer(state.bind.vertex_buffers[0])
    sg.destroy_pipeline(state.pipe)

    sg.shutdown()
}

event :: proc "c" (e: ^sapp.Event) {
    context = ctx

    if e.type == .KEY_DOWN {
        if e.key_code == .ESCAPE do sapp.request_quit()
    }
}
