package main

import "base:runtime"
import "base:intrinsics"
import "core:math"
import "core:log"

import stbi "vendor:stb/image"

import sapp  "sokol:app"
import sg    "sokol:gfx"
import slog  "sokol:log"
import sglue "sokol:glue"
import shelp "sokol:helpers"

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

Vertex_Data :: struct {
    position : Vec3,
    uv       : Vec2,
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
    window_title = "textures",
    icon         = { sokol_default = true },
    logger       = transmute(sapp.Logger)shelp.logger(&ctx),
    })
}

init :: proc "c" () {
    context = ctx

    // setup
    sg.setup({
        logger      = transmute(sg.Logger)shelp.logger(&ctx),
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
    state.shader = sg.make_shader(textures_shader_desc(sg.query_backend()))

    // bind buffers
    vertices := [?]Vertex_Data {
        { position = { -0.5,  0.5, 0.0 }, uv = { 0, 1 }, color = { 1.0, 0.0, 0.0, 1.0 } }, // top left
        { position = {  0.5,  0.5, 0.0 }, uv = { 1, 1 }, color = { 0.0, 1.0, 0.0, 1.0 } }, // top right
        { position = {  0.5, -0.5, 0.0 }, uv = { 1, 0 }, color = { 0.0, 1.0, 1.0, 1.0 } }, // bottom right
        { position = { -0.5, -0.5, 0.0 }, uv = { 0, 0 }, color = { 0.0, 0.0, 1.0, 1.0 } }, // bottom left
    }
    indices := [?]u16 { 0, 1, 2, 2, 3, 0 }

    state.bind.vertex_buffers[0] = sg.make_buffer({
        data  = { ptr = &vertices, size = size_of(vertices) },
        label = "quad_vertices",
    })

    state.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = { ptr = &indices, size = size_of(indices) },
        label = "quad_indices",
    })

    // image
    {
        w, h: i32
        stbi.set_flip_vertically_on_load(true)
        pixels := stbi.load("assets/awesomeface.png", &w, &h, nil, 4)
        defer stbi.image_free(pixels)

        assert(pixels != nil)

        image := sg.make_image({
            width          = w,
            height         = h,
            pixel_format   = .RGBA8,
            data           = {
                mip_levels = {
                    0 = { ptr = pixels, size = uint(w * h * 4) },
                },
            },
        })

        state.bind.views[VIEW_f_texture] = sg.make_view({
            texture = {
                image = image,
            },
        })
    }

    // sampler
    state.bind.samplers[SMP_f_sampler] = sg.make_sampler({})

    // create pipeline
    state.pipe = sg.make_pipeline({
        shader = state.shader,

        layout = {
            attrs = {
                ATTR_textures_position  = { format = .FLOAT3 },
                ATTR_textures_tex_coord = { format = .FLOAT2 },
                ATTR_textures_color     = { format = .FLOAT4 },
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
        label      = "quad_pipeline",
    })

    // pass action
    state.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.0, 0.04, 0.08, 1.0 }}
}

frame :: proc "c" () {
    context = ctx

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pipe)
    sg.apply_bindings(state.bind)

    sg.draw(0, 6, 1)
    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = ctx

    sg.destroy_shader(state.shader)

    sg.destroy_buffer(state.bind.vertex_buffers[0])
    sg.destroy_buffer(state.bind.index_buffer)

    sg.destroy_sampler(state.bind.samplers[SMP_f_sampler])

    sg.destroy_pipeline(state.pipe)

    sg.destroy_image(sg.Image(state.bind.views[VIEW_f_texture]))
    sg.destroy_view(state.bind.views[VIEW_f_texture])

    sg.shutdown()
}

event :: proc "c" (e: ^sapp.Event) {
    context = ctx

    if e.type == .KEY_DOWN {
        if e.key_code == .ESCAPE do sapp.request_quit()
    }
}
