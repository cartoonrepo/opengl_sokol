package main

import "base:runtime"
import "core:fmt"

import slog  "sokol:log"
import sg    "sokol:gfx"
import sapp  "sokol:app"
import sglue "sokol:glue"

pass_action: sg.Pass_Action

init :: proc "c" () {
    context = runtime.default_context()

    sg.setup({
        environment = sglue.environment(),
        logger = { func = slog.func },
    })

    pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.0, 0.05, 0.1, 1.0 }}
}

frame :: proc "c" () {
    context = runtime.default_context()

    sg.begin_pass({ action = pass_action, swapchain = sglue.swapchain() })
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
        window_title = "hello window",
        icon         = { sokol_default = true },
        logger       = { func = slog.func },
    })
}
