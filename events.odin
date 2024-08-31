package main

import "core:strings"
import sdl "vendor:sdl2"

import "parser"
import "render"

process_events :: proc(w: ^render.Window, sidebar: ^render.SideBar, fbox: ^render.FunctionBox, asts: ^[dynamic]parser.Expr) {
    sdl.StartTextInput()
    defer sdl.StopTextInput()
    e: sdl.Event
    for !w.should_close && sdl.PollEvent(&e) {
        #partial switch e.type {
        case .QUIT:
            w.should_close = true
        case .KEYDOWN:
            #partial switch e.key.keysym.sym {
                case .ESCAPE:
                    w.should_close = true
                case .BACKSPACE:
                    strings.pop_rune(&fbox.text)
                    render.function_box_update(fbox, w^)
                    fbox.changed = true
            }
        case .MOUSEBUTTONDOWN:
            w.mousedown = true
            mousepos: [2]i32
            sdl.GetMouseState(&mousepos.x, &mousepos.y)
            if (render.sidebar_process_click(sidebar, mousepos, asts)) {
                w.mousedown = false
            }
        case .MOUSEBUTTONUP:
            w.mousedown = false
        case .MOUSEMOTION:
            if w.mousedown {
                x_motion := f32(e.motion.xrel) / w.zoom
                y_motion := f32(e.motion.yrel) / w.zoom
                w.pos -= { x_motion, -y_motion }
            }
        case .MOUSEWHEEL:
            new_zoom := w.zoom + f32(5*e.wheel.y)
            if new_zoom > min_zoom {
                w.zoom = new_zoom
            }
        case .TEXTINPUT:
            input := cstring(raw_data(e.text.text[:]))
            if strings.builder_len(fbox.text) + len(input) < 50 {
                strings.write_string(&fbox.text, string(input))
                render.function_box_update(fbox, w^)
                fbox.changed = true
            }
        }
    }
}
