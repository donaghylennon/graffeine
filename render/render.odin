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

SideBar :: struct {
    width: i32,
    height: i32,
    add_button: struct { pos: [2]i32, size: i32 },
    selected: int,
    function_boxes: [dynamic]FunctionBox
}

FunctionBox :: struct {
    pos: [2]i32,
    size: [2]i32,
    close_button: struct { pos: [2]i32, size: i32 },
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

sidebar_create :: proc(width: i32, winsize: [2]i32) -> SideBar {
    fbox_size := winsize.y/12
    fbox := function_box_create({0, winsize.y-fbox_size}, {width, fbox_size}, "x^2")
    fboxes := make([dynamic]FunctionBox)
    append(&fboxes, fbox)
    return SideBar {
        width = width,
        height = winsize.y,
        add_button = {
            pos = {0,winsize.y-2*fbox_size},
            size = fbox_size
        },
        selected = 0,
        function_boxes = fboxes
    }
}

sidebar_destroy :: proc(s: SideBar) {
    for &fbox in s.function_boxes {
        function_box_destroy(&fbox)
    }
    delete(s.function_boxes)
}

sidebar_add_function_box :: proc(s: ^SideBar) {
    fbox_size := s.height/12
    prev := s.function_boxes[len(s.function_boxes)-1]
    pos := [2]i32{ prev.pos.x, prev.pos.y-fbox_size }
    fbox := function_box_create(pos, {s.width, fbox_size}, "")
    append(&s.function_boxes, fbox)
    s.selected = len(s.function_boxes)-1
    s.add_button.pos.y -= fbox_size
}

sidebar_process_click :: proc(s: ^SideBar, pos: [2]i32, asts: ^[dynamic]parser.Expr) -> (clicked: bool) {
    if add_button_clicked(s^, pos) {
        clicked = true
        if (len(s.function_boxes) < 12) {
            sidebar_add_function_box(s)
            ast, ok := parser.parse(strings.to_string(s.function_boxes[s.selected].text))
            if ok {
                append(asts, ast)
            }
        }
    } else {
        for fbox, index in s.function_boxes {
            if function_box_clicked(fbox, pos) {
                clicked = true
                if close_button_clicked(fbox, pos) {
                    remove_function_box(s, asts, index)
                    if s.selected > len(s.function_boxes)-1 {
                        s.selected -= 1
                    }
                } else {
                    s.selected = index
                }
                break
            }
        }
    }
    return
}

add_button_clicked :: proc(s: SideBar, pos: [2]i32) -> (clicked: bool) {
    within_x := (pos.x >= s.add_button.pos.x && pos.x < s.add_button.pos.x+s.add_button.size)
    within_y := (pos.y >= s.add_button.pos.y && pos.y <s.add_button.pos.y+s.add_button.size)
    return within_x && within_y
}

function_box_clicked :: proc(fbox: FunctionBox, pos: [2]i32) -> (clicked: bool) {
    within_x := (pos.x >= fbox.pos.x && pos.x < fbox.pos.x+fbox.size.x)
    within_y := (pos.y >= fbox.pos.y && pos.y < fbox.pos.y+fbox.size.y)
    return within_x && within_y
}

close_button_clicked :: proc(fbox: FunctionBox, pos: [2]i32) -> (clicked: bool) {
    within_x := (pos.x >= fbox.close_button.pos.x && pos.x < fbox.close_button.pos.x+fbox.close_button.size)
    within_y := (pos.y >= fbox.close_button.pos.y && pos.y < fbox.close_button.pos.y+fbox.close_button.size)
    return within_x && within_y
}

remove_function_box :: proc(s: ^SideBar, asts: ^[dynamic]parser.Expr, index: int) {
    if !(index > len(s.function_boxes)-1) && len(s.function_boxes) > 1 {
        for &fbox in s.function_boxes[index+1:] {
            fbox.pos.y += fbox.size.y
            fbox.close_button.pos.y += fbox.size.y
        }
        s.add_button.pos.y += s.add_button.size
        ordered_remove(&s.function_boxes, index)
        ordered_remove(asts, index)
    }
}

draw_sidebar :: proc(w: Window, s: SideBar) {
    add_button_rect := sdl.Rect{s.add_button.pos.x, s.add_button.pos.y, s.add_button.size, s.add_button.size}
    sdl.RenderFillRect(w.sdl_renderer, &add_button_rect)
    sdl.SetRenderDrawColor(w.sdl_renderer, 0,0,0,255)
    sdl.RenderDrawLine(w.sdl_renderer, s.add_button.pos.x + s.add_button.size/2, s.add_button.pos.y + s.add_button.size/3,
                                        s.add_button.pos.x + s.add_button.size/2, s.add_button.pos.y + s.add_button.size*2/3)
    sdl.RenderDrawLine(w.sdl_renderer, s.add_button.pos.x + s.add_button.size/3, s.add_button.pos.y + s.add_button.size/2,
                                        s.add_button.pos.x + s.add_button.size*2/3, s.add_button.pos.y + s.add_button.size/2)
    for fbox in s.function_boxes {
        draw_function_box(w, fbox)
    }
}

function_box_create :: proc(pos, size: [2]i32, text: string) -> FunctionBox {
    builder := strings.builder_make()
    strings.write_string(&builder, text)
    return FunctionBox {
        pos = pos,
        size = size,
        close_button = {
            pos = { pos.x + size.x - size.y, pos.y },
            size = size.y
        },
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
    close_button_size := fbox.close_button.size
    close_button_pos := fbox.close_button.pos
    rect := sdl.Rect { fbox.pos.x, fbox.pos.y, fbox.size.x-close_button_size, fbox.size.y }
    close_button_rect := sdl.Rect { close_button_pos.x, close_button_pos.y, close_button_size, close_button_size }
    sdl.SetRenderDrawColor(w.sdl_renderer, 130, 170, 240, 255)
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

real_to_screen :: proc(point: [2]f32, window: Window) -> [2]f32 {
    return { (point.x - window.pos.x) * window.zoom, f32(window.size.y) - (point.y - window.pos.y)*window.zoom }
}

real_x_to_screen_x :: proc(x: f32, window: Window) -> f32 {
    return f32(window.size.x) - (x - window.pos.x)*window.zoom
}

real_y_to_screen_y :: proc(y: f32, window: Window) -> f32 {
    return f32(window.size.y) - (y - window.pos.y)*window.zoom
}

