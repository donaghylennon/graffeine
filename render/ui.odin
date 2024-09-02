package render

import "core:strings"
import "core:os"
import "core:fmt"

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
    mousedown: bool,
    sidebar: SideBar
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
    text: strings.Builder
}

create_window :: proc(winsize: [2]i32, pos: [2]f32, zoom: f32) -> Window {
    win := sdl.CreateWindow("Graffeine", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, winsize.x, winsize.y, sdl.WINDOW_SHOWN)
    ren := sdl.CreateRenderer(win, -1, sdl.RENDERER_ACCELERATED)
    font := ttf.OpenFont("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 24)
    if font == nil {
        fmt.eprintln("Error loading font")
        os.exit(1)
    }

    w := Window {
        sdl_window = win,
        sdl_renderer = ren,
        sdl_font = font,
        pos = pos,
        size = winsize,
        zoom = zoom,
        should_close = false,
        mousedown = false,
        sidebar = sidebar_create(winsize.x/4, winsize)
    }
    function_box_update(&w.sidebar.function_boxes[w.sidebar.selected], w)
    return w
}

destroy_window :: proc(w: ^Window) {
    ttf.CloseFont(w.sdl_font)
    sdl.DestroyRenderer(w.sdl_renderer)
    sdl.DestroyWindow(w.sdl_window)
    sidebar_destroy(w.sidebar)
    w.sdl_font = nil
    w.sdl_renderer = nil
    w.sdl_window = nil
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

real_to_screen :: proc(point: [2]f32, window: Window) -> [2]f32 {
    return { (point.x - window.pos.x) * window.zoom, f32(window.size.y) - (point.y - window.pos.y)*window.zoom }
}

real_x_to_screen_x :: proc(x: f32, window: Window) -> f32 {
    return f32(window.size.x) - (x - window.pos.x)*window.zoom
}

real_y_to_screen_y :: proc(y: f32, window: Window) -> f32 {
    return f32(window.size.y) - (y - window.pos.y)*window.zoom
}

window_process_mousemotion :: proc(w: ^Window, x, y: i32) {
    if w.mousedown {
        x_motion := f32(x) / w.zoom
        y_motion := f32(y) / w.zoom
        w.pos -= {x_motion, -y_motion}
    }
}

window_process_textinput :: proc(w: ^Window, asts: ^[dynamic]parser.Expr, text: cstring) {
    selected := w.sidebar.selected
    fbox := &w.sidebar.function_boxes[selected]
    if strings.builder_len(fbox.text) + len(text) < 50 {
        strings.write_string(&fbox.text, string(text))
        function_box_update(fbox, w^)

        ast := &asts[selected]
        update_ast(ast, strings.to_string(fbox.text))
    }
}

update_ast :: proc(ast: ^parser.Expr, text: string) {
    parser.destroy_ast(ast^)
    ok: bool
    ast^, ok = parser.parse(text)
}

window_process_mousewheel :: proc(w: ^Window, y: i32) {
    min_zoom :: 5
    new_zoom := w.zoom + f32(5*y)
    if new_zoom > min_zoom {
        w.zoom = new_zoom
    }
}

window_process_click :: proc(w: ^Window, asts: ^[dynamic]parser.Expr, mousepos: [2]i32) {
    w.mousedown = true
    if (sidebar_process_click(&w.sidebar, mousepos, asts)) {
        w.mousedown = false
    }
}

window_process_keydown :: proc(w: ^Window, asts: ^[dynamic]parser.Expr, sym: sdl.Keycode) {
    #partial switch sym {
        case .ESCAPE:
            w.should_close = true
        case .BACKSPACE:
            selected := w.sidebar.selected
            fbox := &w.sidebar.function_boxes[selected]
            strings.pop_rune(&fbox.text)
            function_box_update(fbox, w^)

            ast := &asts[selected]
            update_ast(ast, strings.to_string(fbox.text))
    }
}
