package main

import "core:fmt"
import "core:log"
import "core:math/linalg"

import "base:runtime"
import "base:intrinsics"

import stbi "vendor:stb/image"

import sapp  "sokol:app"
import sg    "sokol:gfx"
import sglue "sokol:glue"
import slog  "sokol:log"
import shelp "sokol:helpers"

Vec2 :: [2]f32
Vec3 :: [3]f32
Mat4 :: matrix[4, 4]f32

Vertex_Data :: struct {
    position : Vec3,
    uv       : Vec2,
    color    : sg.Color,
}

ROTATION_SPEED :: 90

State :: struct {
    shader        : sg.Shader,
    pipeline      : sg.Pipeline,
    bindings      : sg.Bindings,
    pass_action   : sg.Pass_Action,
    image         : sg.Image,
    rotation      : f32,
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
        window_title = "Part_3: Rotating Wall",
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
                ATTR_main_position = { format = .FLOAT3 },
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
    WHITE :: sg.Color { 1.0, 1.0, 1.0, 1.0 }

    vertices := []Vertex_Data {
        { position = { -0.5,  0.5, 0.0 }, uv = { 0, 1 }, color = WHITE }, // top left
        { position = {  0.5,  0.5, 0.0 }, uv = { 1, 1 }, color = WHITE }, // top right
        { position = {  0.5, -0.5, 0.0 }, uv = { 1, 0 }, color = WHITE }, // bottom right
        { position = { -0.5, -0.5, 0.0 }, uv = { 0, 0 }, color = WHITE }, // bottom left
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
    // pixels := stbi.load("assets/awesomeface.png", &w, &h, nil, 4)
    pixels := stbi.load("assets/BRICK_1A.PNG", &w, &h, nil, 4)
    // pixels := stbi.load("assets/FLOOR_3A.PNG", &w, &h, nil, 4)

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
            0 = { load_action = .CLEAR, store_action = .DEFAULT, clear_value = { 0.0, 0.04, 0.08, 1.0 } },
        },
    }
}

frame :: proc "c" () {
    context = ctx

    dt := f32(sapp.frame_duration())

    state.rotation += linalg.to_radians(ROTATION_SPEED * dt)

    p := linalg.matrix4_perspective_f32(70, sapp.widthf() / sapp.heightf(), 0.01, 1000)
    m := linalg.matrix4_translate_f32({ 0.0, 0.0, -2.0 }) * linalg.matrix4_from_yaw_pitch_roll_f32(state.rotation, 0, 0)

    vs_params := Vs_Params {
        mvp = p * m,
    }

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })

    sg.apply_pipeline(state.pipeline)
    sg.apply_bindings(state.bindings)
    sg.apply_uniforms(UB_Vs_Params, sg_range(&vs_params))

    sg.draw(0, 6, 1)

    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = ctx

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
    context = ctx

    #partial switch e.type {
    case .KEY_DOWN:
        #partial switch e.key_code {
        case .ESCAPE:
            sapp.request_quit()
        }
    }
}

sg_range :: proc {
    sg_range_from_struct,
    sg_range_from_slice,
}

sg_range_from_struct :: proc(s: ^$T) -> sg.Range where intrinsics.type_is_struct(T) {
    return {
        ptr  = s,
        size = size_of(T),
    }
}

sg_range_from_slice :: proc(s: []$T) -> sg.Range {
    return {
        ptr  = raw_data(s),
        size = len(s) * size_of(s[0]),
    }
}
