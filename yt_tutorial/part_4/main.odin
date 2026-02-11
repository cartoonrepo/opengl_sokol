package main

import "core:fmt"
import "core:log"

import "core:math"
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
Vec4 :: [4]f32
Mat4 :: matrix[4, 4]f32

ROTATION_SPEED   :: 90
MOVE_SPEED       :: 3
LOOK_SENSITIVITY :: 0.2

WHITE :: sg.Color { 1.0, 1.0, 1.0, 1.0 }

Vertex_Data :: struct {
    position : Vec3,
    uv       : Vec2,
    color    : sg.Color,
}

Object :: struct {
    pos  : Vec3,
    rot  : Vec3,
    view : sg.View,
}

State :: struct {
    shader        : sg.Shader,
    pipeline      : sg.Pipeline,
    bindings      : sg.Bindings,
    pass_action   : sg.Pass_Action,
    views         : [2]sg.View,
    rotation      : f32,
    camera        : struct {
        position : Vec3,
        target   : Vec3,
        look     : Vec2,
    },
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
        window_title = "Part_4: Camera Control",
        icon         = { sokol_default = true },
        logger       = transmute(sapp.Logger)shelp.logger(&ctx), // app logger
    })
}

init :: proc "c" () {
    context = ctx

    sapp.lock_mouse(true)

    sg.setup({
        environment = sglue.environment(),
        logger      = transmute(sg.Logger)shelp.logger(&ctx), // gfx logger
    })

    state = new(State)

    state.camera = {
        position = { 0, 0, 2 } ,
        target   = { 0, 0, 1 } ,
    }

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
        depth = {
            compare       = .LESS_EQUAL,
            write_enabled = true,
        },
    })

    // vertex buffer
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

    // views
    state.views[0] = sg.make_view({
        texture = {
            image = load_image("assets/BRICK_1A.PNG"),
        },
    })

    state.views[1] = sg.make_view({
        texture = {
            image = load_image("assets/FLOOR_3A.PNG"),
        },
    })

    // sampler
    state.bindings.samplers[SMP_smp] = sg.make_sampler({})

    // pass action
    state.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, store_action = .DEFAULT, clear_value = { 0.0, 0.04, 0.08, 1.0 } },
        },
    }
}

load_image :: proc(file_name: cstring) -> sg.Image {
    w, h: i32
    stbi.set_flip_vertically_on_load(true)

    pixels := stbi.load(file_name, &w, &h, nil, 4)

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

    stbi.image_free(pixels)

    return image
}

frame :: proc "c" () {
    context = ctx

    // lock mouse after resizing window
    if !sapp.mouse_locked() do sapp.lock_mouse(true)

    if key_down[.ESCAPE] do sapp.request_quit()

    dt := f32(sapp.frame_duration())

    update_camera(dt)

    p := linalg.matrix4_perspective_f32(70, sapp.widthf() / sapp.heightf(), 0.01, 100)
    v := linalg.matrix4_look_at_f32(state.camera.position, state.camera.target, { 0, 1, 0 })

    objects := [?]Object {
        {{ 0, 0, 0 }, { 0, 0, 0 }, state.views[0] },
        {{ 1, 0, 0 }, { 0, 0, 0 }, state.views[0] },
        {{ 2, 0, 0 }, { 0, 0, 0 }, state.views[0] },

        {{ 0, 0, 2 }, { 0, 0, 0 }, state.views[0] },
        {{ 1, 0, 2 }, { 0, 0, 0 }, state.views[0] },
        {{ 2, 0, 2 }, { 0, 0, 0 }, state.views[0] },

        {{ 0, -0.5, 0.5 }, { 90, 0, 0 }, state.views[1] },
        {{ 1, -0.5, 0.5 }, { 90, 0, 0 }, state.views[1] },
        {{ 2, -0.5, 0.5 }, { 90, 0, 0 }, state.views[1] },
        {{ 0, -0.5, 1.5 }, { 90, 0, 0 }, state.views[1] },
        {{ 1, -0.5, 1.5 }, { 90, 0, 0 }, state.views[1] },
        {{ 2, -0.5, 1.5 }, { 90, 0, 0 }, state.views[1] },
    }

    sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pipeline)

    for obj in objects {
        state.bindings.views[VIEW_tex] = obj.view

        m := linalg.matrix4_translate_f32(obj.pos) * linalg.matrix4_from_yaw_pitch_roll_f32(linalg.to_radians(obj.rot.y), linalg.to_radians(obj.rot.x), linalg.to_radians(obj.rot.z))

        sg.apply_bindings(state.bindings)
        sg.apply_uniforms(UB_Vs_Params, sg_range(&Vs_Params { mvp = p * v * m }))
        sg.draw(0, 6, 1)
    }

    sg.end_pass()
    sg.commit()

    mouse_move = 0
}

cleanup :: proc "c" () {
    context = ctx

    sg.destroy_buffer(state.bindings.vertex_buffers[0])
    sg.destroy_buffer(state.bindings.index_buffer)

    sg.destroy_sampler(state.bindings.samplers[SMP_smp])
    sg.destroy_pipeline(state.pipeline)

    for v in state.views {
        // idk, image and view share same id, do i have to destroy both or just destroy_view is enough
        sg.destroy_image(sg.Image(v))
        sg.destroy_view(v)
    }

    sg.destroy_shader(state.shader)

    free(state)
    sg.shutdown()
}

mouse_move: Vec2
key_down: #sparse[sapp.Keycode]bool

event :: proc "c" (e: ^sapp.Event) {
    context = ctx

    #partial switch e.type {
    case .KEY_DOWN:
        key_down[e.key_code] = true

    case .KEY_UP:
        key_down[e.key_code] = false

    case .MOUSE_MOVE:
        mouse_move += { e.mouse_dx, e.mouse_dy }
    }
}

update_camera :: proc(dt: f32) {
    move_input: Vec2
    if key_down[.W] do move_input.y =  1
    if key_down[.S] do move_input.y = -1
    if key_down[.A] do move_input.x = -1
    if key_down[.D] do move_input.x =  1

    look_input: Vec2 = -mouse_move * LOOK_SENSITIVITY
    state.camera.look += look_input

    state.camera.look.x = math.wrap(state.camera.look.x, 360)
    state.camera.look.y = math.clamp(state.camera.look.y, -90, 90)

    look_mat := linalg.matrix4_from_yaw_pitch_roll_f32(linalg.to_radians(state.camera.look.x), linalg.to_radians(state.camera.look.y), 0)

    forward := (look_mat * Vec4 { 0, 0, -1, 1 }).xyz
    right   := (look_mat * Vec4 { 1, 0,  0, 1 }).xyz

    move_dir := forward * move_input.y + right * move_input.x

    motion := linalg.normalize0(move_dir) * MOVE_SPEED * dt
    state.camera.position += motion

    state.camera.target = state.camera.position + forward
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
