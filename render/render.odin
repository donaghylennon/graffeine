package render

import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:fmt"
import "core:os"
import sdl "vendor:sdl2"
import ttf "vendor:sdl2/ttf"

import "../parser"

Window :: struct {
    sdl_window: ^sdl.Window,
    sdl_renderer: ^sdl.Renderer,
    sdl_font: ^ttf.Font,
    pos: [2]f32,
    size: [2]i32,
    zoom: f32,
    should_close: bool,
    mousedown: bool
}

FunctionBox :: struct {
    pos: [2]i32,
    size: [2]i32,
    texture: ^sdl.Texture,
    text_width: i32,
    changed: bool,
    text: strings.Builder
}

init :: proc() {
    sdl.Init(sdl.INIT_VIDEO | sdl.INIT_EVENTS)
    ttf.Init()
}

quit :: proc() {
    ttf.Quit()
    sdl.Quit()
}

create_window :: proc(winsize: [2]i32, pos: [2]f32, zoom: f32) -> Window {
    win := sdl.CreateWindow("Graffeine", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, winsize.x, winsize.y, sdl.WINDOW_SHOWN)
    ren := sdl.CreateRenderer(win, -1, sdl.RENDERER_ACCELERATED)
    font := ttf.OpenFont("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 24)
    if font == nil {
        fmt.eprintln("Error loading font")
        os.exit(1)
    }

    return Window {
        sdl_window = win,
        sdl_renderer = ren,
        sdl_font = font,
        pos = pos,
        size = winsize,
        zoom = zoom,
        should_close = false,
        mousedown = false
    }
}

destroy_window :: proc(w: ^Window) {
    ttf.CloseFont(w.sdl_font)
    sdl.DestroyRenderer(w.sdl_renderer)
    sdl.DestroyWindow(w.sdl_window)
    w.sdl_font = nil
    w.sdl_renderer = nil
    w.sdl_window = nil
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

draw_sine :: proc(renderer: ^sdl.Renderer, window: Window) {
    fx := math.sin(f32(-1))
    prev_screen_y := real_y_to_screen_y(fx, window)
    for screen_x in 0..<window.size.x {
        x := window.pos.x + f32(screen_x)/window.zoom
        fx = math.sin(x)
        screen_y := real_y_to_screen_y(fx, window)
        sdl.RenderDrawLineF(renderer, f32(screen_x-1), prev_screen_y, f32(screen_x), screen_y)

        prev_screen_y = screen_y
    }
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

function_box_create :: proc(pos, size: [2]i32, text: string) -> FunctionBox {
    builder := strings.builder_make()
    strings.write_string(&builder, text)
    return FunctionBox {
        pos = pos,
        size = size,
        texture = nil,
        text_width = 0,
        changed = false,
        text = builder
    }
}

function_box_destroy :: proc(fbox: ^FunctionBox) {
    if fbox.texture != nil {
        sdl.DestroyTexture(fbox.texture)
        fbox.texture = nil
    }
    strings.builder_destroy(&fbox.text)
}

function_box_update :: proc(fbox: ^FunctionBox, w: Window) {
    if fbox.texture != nil {
        sdl.DestroyTexture(fbox.texture)
    }
    text: cstring
    if strings.builder_len(fbox.text) > 0 {
        text = strings.to_cstring(&fbox.text)
    } else {
        text = " "
    }
    surface := ttf.RenderText_Solid(w.sdl_font, text, {0,0,0,255})
    fbox.texture = sdl.CreateTextureFromSurface(w.sdl_renderer, surface)
    fbox.text_width = surface.w
    sdl.FreeSurface(surface)
}

draw_function_box :: proc(w: Window, fbox: FunctionBox) {
    rect := sdl.Rect { fbox.pos.x, fbox.pos.y, fbox.size.x, fbox.size.y }
    sdl.SetRenderDrawColor(w.sdl_renderer, 130, 170, 240, 255)
    sdl.RenderFillRect(w.sdl_renderer, &rect)
    sdl.SetRenderDrawColor(w.sdl_renderer, 0, 0, 0, 255)
    sdl.RenderDrawRect(w.sdl_renderer, &rect)
    close_button_rect := sdl.Rect { fbox.pos.x+fbox.size.x, fbox.pos.y, fbox.size.y, fbox.size.y }
    sdl.SetRenderDrawColor(w.sdl_renderer, 230, 140, 75, 255)
    sdl.RenderFillRect(w.sdl_renderer, &close_button_rect)
    sdl.SetRenderDrawColor(w.sdl_renderer, 0, 0, 0, 255)
    sdl.RenderDrawRect(w.sdl_renderer, &close_button_rect)
    sdl.RenderDrawLine(w.sdl_renderer, fbox.pos.x+fbox.size.x+fbox.size.y/8, fbox.pos.y+fbox.size.y/8,
                                    fbox.pos.x+fbox.size.x+fbox.size.y-(fbox.size.y/8), fbox.pos.y+fbox.size.y-(fbox.size.y/8))
    sdl.RenderDrawLine(w.sdl_renderer, fbox.pos.x+fbox.size.x+fbox.size.y-(fbox.size.y/8), fbox.pos.y+fbox.size.y/8,
                                    fbox.pos.x+fbox.size.x+fbox.size.y/8, fbox.pos.y+fbox.size.y-(fbox.size.y/8))

    text_width := fbox.text_width
    text_rect := sdl.Rect { fbox.pos.x, fbox.pos.y, text_width, fbox.size.y}
    sdl.RenderCopy(w.sdl_renderer, fbox.texture, nil, &text_rect)
}

real_to_screen :: proc(point: [2]f32, window: Window) -> [2]f32 {
    return { (point.x - window.pos.x) * window.zoom, f32(window.size.y) - (point.y - window.pos.y)*window.zoom }
}

real_x_to_screen_x :: proc(x: f32, window: Window) -> f32 {
    return f32(window.size.x) - (x - window.pos.x)*window.zoom
}

real_y_to_screen_y :: proc(y: f32, window: Window) -> f32 {
    return f32(window.size.y) - (y - window.pos.y)*window.zoom
}

