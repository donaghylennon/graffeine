package render

import "core:math/linalg"
import sdl "vendor:sdl2"
import ttf "vendor:sdl2/ttf"

import "../parser"

init :: proc() {
    sdl.Init(sdl.INIT_VIDEO | sdl.INIT_EVENTS)
    ttf.Init()
}

quit :: proc() {
    ttf.Quit()
    sdl.Quit()
}

clear :: proc(w: Window) {
    sdl.SetRenderDrawColor(w.sdl_renderer, 255, 255, 255, 255)
    sdl.RenderClear(w.sdl_renderer)
}

present :: proc(w: Window) {
    sdl.RenderPresent(w.sdl_renderer)
}

get_time :: proc() -> f64 {
    return f64(sdl.GetPerformanceCounter()) / f64(sdl.GetPerformanceFrequency())
}

draw_graph :: proc(w: Window, ast: parser.Expr) {
    sdl.SetRenderDrawColor(w.sdl_renderer, 225, 20, 30, 255)
    prev_screen_y := f32(0)
    for screen_x in 0..<w.size.x {
        x := w.pos.x + f32(screen_x)/w.zoom
        fx, ok := parser.evaluate_function(ast, x)
        if !ok {
            return
        }
        screen_y := real_y_to_screen_y(fx, w)
        sdl.RenderDrawLineF(w.sdl_renderer, f32(screen_x-1), prev_screen_y, f32(screen_x), screen_y)

        prev_screen_y = screen_y
    }
}

draw_grid :: proc(w: Window, interval: f32) {
    sdl.SetRenderDrawColor(w.sdl_renderer, 0, 0, 0, 255)
    draw_axes(w.sdl_renderer, w)
    num_lines := (linalg.to_f32(w.size)/interval)/w.zoom
    screen_interval := interval * w.zoom
    mod_pos := linalg.mod(w.pos, interval)
    offset := interval - mod_pos
    for line in 0..<num_lines.x {
        x_line := (offset.x*w.zoom + line*screen_interval)
        sdl.RenderDrawLine(w.sdl_renderer, i32(x_line), w.size.y, i32(x_line), 0)
    }
    for line in 0..<num_lines.y {
        y_line := f32(w.size.y) - (offset.y*w.zoom + line*screen_interval)
        sdl.RenderDrawLine(w.sdl_renderer, w.size.x, i32(y_line), 0, i32(y_line))
    }
}

draw_axes :: proc(renderer: ^sdl.Renderer, window: Window) {
    screen_pos := real_to_screen({}, window)
    if screen_pos.x >=0 && screen_pos.x < f32(window.size.x) {
        sdl.RenderDrawLineF(renderer, screen_pos.x, 0, screen_pos.x, f32(window.size.y))
        sdl.RenderDrawLineF(renderer, screen_pos.x+1, 0, screen_pos.x+1, f32(window.size.y))
        sdl.RenderDrawLineF(renderer, screen_pos.x-1, 0, screen_pos.x-1, f32(window.size.y))
    }
    if screen_pos.y >=0 && screen_pos.y < f32(window.size.y) {
        sdl.RenderDrawLineF(renderer, 0, screen_pos.y,   f32(window.size.x), screen_pos.y)
        sdl.RenderDrawLineF(renderer, 0, screen_pos.y+1, f32(window.size.x), screen_pos.y+1)
        sdl.RenderDrawLineF(renderer, 0, screen_pos.y-1, f32(window.size.x), screen_pos.y-1)
    }
}

draw_sidebar :: proc(w: Window, s: SideBar) {
    add_button_rect := sdl.Rect{s.add_button.pos.x, s.add_button.pos.y, s.add_button.size, s.add_button.size}
    sdl.SetRenderDrawColor(w.sdl_renderer, 45,230,30,255)
    sdl.RenderFillRect(w.sdl_renderer, &add_button_rect)
    sdl.SetRenderDrawColor(w.sdl_renderer, 0,0,0,255)
    sdl.RenderDrawRect(w.sdl_renderer, &add_button_rect)
    sdl.RenderDrawLine(w.sdl_renderer, s.add_button.pos.x + s.add_button.size/2, s.add_button.pos.y + s.add_button.size/3,
                                        s.add_button.pos.x + s.add_button.size/2, s.add_button.pos.y + s.add_button.size*2/3)
    sdl.RenderDrawLine(w.sdl_renderer, s.add_button.pos.x + s.add_button.size/3, s.add_button.pos.y + s.add_button.size/2,
                                        s.add_button.pos.x + s.add_button.size*2/3, s.add_button.pos.y + s.add_button.size/2)
    color := [3]u8 {130, 170, 240}
    for fbox, i in s.function_boxes {
        draw_function_box(w, fbox, color)
    }
}

draw_function_box :: proc(w: Window, fbox: FunctionBox, color: [3]u8) {
    close_button_size := fbox.close_button.size
    close_button_pos := fbox.close_button.pos
    rect := sdl.Rect { fbox.pos.x, fbox.pos.y, fbox.size.x-close_button_size, fbox.size.y }
    close_button_rect := sdl.Rect { close_button_pos.x, close_button_pos.y, close_button_size, close_button_size }
    sdl.SetRenderDrawColor(w.sdl_renderer, color.r, color.g, color.b, 255)
    sdl.RenderFillRect(w.sdl_renderer, &rect)
    sdl.SetRenderDrawColor(w.sdl_renderer, 0, 0, 0, 255)
    sdl.RenderDrawRect(w.sdl_renderer, &rect)

    sdl.SetRenderDrawColor(w.sdl_renderer, 230, 140, 75, 255)
    sdl.RenderFillRect(w.sdl_renderer, &close_button_rect)
    sdl.SetRenderDrawColor(w.sdl_renderer, 0, 0, 0, 255)
    sdl.RenderDrawRect(w.sdl_renderer, &close_button_rect)
    sdl.RenderDrawLine(w.sdl_renderer, close_button_pos.x+close_button_size/8, close_button_pos.y+close_button_size/8,
                                    close_button_pos.x+close_button_size-(close_button_size/8), close_button_pos.y+close_button_size-(close_button_size/8))
    sdl.RenderDrawLine(w.sdl_renderer, close_button_pos.x+close_button_size-(close_button_size/8), close_button_pos.y+close_button_size/8,
                                    close_button_pos.x+close_button_size/8, close_button_pos.y+close_button_size-(close_button_size/8))

    text_width := fbox.text_width
    text_rect := sdl.Rect { fbox.pos.x, fbox.pos.y, text_width, fbox.size.y}
    sdl.RenderCopy(w.sdl_renderer, fbox.texture, nil, &text_rect)
}
