package main

import "core:strings"
import sdl "vendor:sdl2"

import "parser"
import "render"

process_events :: proc(w: ^render.Window, asts: ^[dynamic]parser.Expr) {
    sdl.StartTextInput()
    defer sdl.StopTextInput()
    e: sdl.Event
    for !w.should_close && sdl.PollEvent(&e) {
        #partial switch e.type {
        case .QUIT:
            w.should_close = true
        case .KEYDOWN:
            render.window_process_keydown(w, asts, e.key.keysym.sym)
        case .MOUSEBUTTONDOWN:
            mousepos: [2]i32
            sdl.GetMouseState(&mousepos.x, &mousepos.y)
            render.window_process_click(w, asts, mousepos)
        case .MOUSEBUTTONUP:
            w.mousedown = false
        case .MOUSEMOTION:
            render.window_process_mousemotion(w, e.motion.xrel, e.motion.yrel)
        case .MOUSEWHEEL:
            render.window_process_mousewheel(w, e.wheel.y)
        case .TEXTINPUT:
            render.window_process_textinput(w, asts, cstring(raw_data(e.text.text[:])))
        }
    }
}
