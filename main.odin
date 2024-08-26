package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:os"
import sdl "vendor:sdl2"
import ttf "vendor:sdl2/ttf"

import "parser"

winsize : [2]i32 : { 1200, 800 }
gridsize : [2]i32 : winsize

min_zoom :: 5

Window :: struct {
    pos: [2]f32,
    size: [2]i32,
    zoom: f32
}

FunctionBox :: struct {
    pos: [2]i32,
    size: [2]i32,
    texture: ^sdl.Texture,
    text_width: i32,
    text: strings.Builder
}

main :: proc() {
    sdl.Init(sdl.INIT_VIDEO | sdl.INIT_EVENTS)
    defer sdl.Quit()
    ttf.Init()
    defer ttf.Quit()

    win := sdl.CreateWindow("Graffeine", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, winsize.x, winsize.y, sdl.WINDOW_SHOWN)
    defer sdl.DestroyWindow(win)

    renderer := sdl.CreateRenderer(win, -1, sdl.RENDERER_ACCELERATED)
    defer sdl.DestroyRenderer(renderer)


    rect := sdl.Rect {0, 0, 40, 30}
    vel := [2]f64 { 200, 200 }
    color := [4]u8 { 255, 255, 255, 255 }

    ast, ok := parser.parse("sin(x*2) + 30")
    if ok {
        parser.print_ast(ast)
    }
    defer parser.destroy_ast(ast)

    font := ttf.OpenFont("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 24)
    if font == nil {
        fmt.eprintln("Error loading font")
        os.exit(1)
    }
    defer ttf.CloseFont(font)

    window := Window {
        pos  = {-1, -1},
        size = winsize,
        zoom = 50
    }

    fbox_builder := strings.builder_make()
    defer strings.builder_destroy(&fbox_builder)
    fbox := FunctionBox {
        pos = {0, window.size.y - 50},
        size = {250, 50},
        texture = nil,
        text_width = 0,
        text = fbox_builder
    }


    fps :: 60
    frame_time := 1/f64(fps)

    get_time :: proc() -> f64 { return f64(sdl.GetPerformanceCounter()) / f64(sdl.GetPerformanceFrequency()) }

    last_frame_time := get_time()
    mousedown := false
    done := false
    for !done {
        time := get_time()
        dt := time - last_frame_time
        if (dt < frame_time) do continue
        last_frame_time = get_time()

        sdl.SetRenderDrawColor(renderer, 255, 255, 255, 255)
        sdl.RenderClear(renderer)

        sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
        grid_interval := f32(1)
        draw_grid(renderer, window, grid_interval)
        sdl.SetRenderDrawColor(renderer, 225, 20, 30, 255)
        draw_sine(renderer, window)

        draw_function_box(renderer, fbox)


        sdl.RenderPresent(renderer)


        sdl.StartTextInput()
        defer sdl.StopTextInput()
        e: sdl.Event
        for sdl.PollEvent(&e) {
            #partial switch e.type {
                case .QUIT:
                    done = true
                case .KEYDOWN:
                    #partial switch e.key.keysym.sym {
                        case .ESCAPE:
                            done = true
                        case .BACKSPACE:
                            strings.pop_rune(&fbox.text)
                            function_box_update(&fbox, renderer, font)
                    }
                case .MOUSEBUTTONDOWN:
                    mousedown = true
                case .MOUSEBUTTONUP:
                    mousedown = false
                case .MOUSEMOTION:
                    if mousedown {
                        x_motion := f32(e.motion.xrel) / window.zoom
                        y_motion := f32(e.motion.yrel) / window.zoom
                        window.pos -= { x_motion, -y_motion }
                    }
                case .MOUSEWHEEL:
                    new_zoom := window.zoom + f32(5*e.wheel.y)
                    if new_zoom > min_zoom {
                        window.zoom = new_zoom
                    }
                case .TEXTINPUT:
                    input := cstring(raw_data(e.text.text[:]))
                    if strings.builder_len(fbox.text) + len(input) < 20 {
                        strings.write_string(&fbox.text, string(input))
                        function_box_update(&fbox, renderer, font)
                    }
            }
        }
    }
}

bounce_rect :: proc(renderer: ^sdl.Renderer, rect: ^sdl.Rect, vel: ^[2]f64, color: ^[4]u8, dt: f64) {
    color.r = u8(f32(rect.x)/f32(winsize.x) * 255)
    color.g = u8(f32(rect.y)/f32(winsize.y) * 255)
    color.b = u8(f32(rect.x + rect.y)/f32(winsize.x+winsize.y) * 255)
    sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
    sdl.RenderFillRect(renderer, rect)
    rect.x += i32(dt * vel.x)
    rect.y += i32(dt * vel.y)
    if (rect.x + rect.w > winsize.x) {
        vel.x = -vel.x
        rect.x = winsize.x - rect.w
    } else if (rect.x < 0) {
        vel.x = -vel.x
        rect.x = 0
    }
    if (rect.y + rect.h > winsize.y) {
        vel.y = -vel.y
        rect.y = winsize.y - rect.h
    } else if (rect.y < 0) {
        vel.y = -vel.y
        rect.y = 0
    }
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

real_to_screen :: proc(point: [2]f32, window: Window) -> [2]f32 {
    return { (point.x - window.pos.x) * window.zoom, f32(window.size.y) - (point.y - window.pos.y)*window.zoom }
}

real_x_to_screen_x :: proc(x: f32, window: Window) -> f32 {
    return f32(window.size.x) - (x - window.pos.x)*window.zoom
}

real_y_to_screen_y :: proc(y: f32, window: Window) -> f32 {
    return f32(window.size.y) - (y - window.pos.y)*window.zoom
}

draw_grid :: proc(renderer: ^sdl.Renderer, window: Window, interval: f32) {
    draw_axes(renderer, window)
    num_lines := (linalg.to_f32(window.size)/interval)/window.zoom
    screen_interval := interval * window.zoom
    mod_pos := linalg.mod(window.pos, interval)
    offset := interval - mod_pos
    for line in 0..<num_lines.x {
        x_line := (offset.x*window.zoom + line*screen_interval)
        sdl.RenderDrawLine(renderer, i32(x_line), window.size.y, i32(x_line), 0)
    }
    for line in 0..<num_lines.y {
        y_line := f32(window.size.y) - (offset.y*window.zoom + line*screen_interval)
        sdl.RenderDrawLine(renderer, window.size.x, i32(y_line), 0, i32(y_line))
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

draw_function_box :: proc(renderer: ^sdl.Renderer, fbox: FunctionBox) {
    rect := sdl.Rect { fbox.pos.x, fbox.pos.y, fbox.size.x, fbox.size.y }
    sdl.SetRenderDrawColor(renderer, 240, 240, 200, 255)
    sdl.RenderFillRect(renderer, &rect)
    sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
    sdl.RenderDrawRect(renderer, &rect)

    w := fbox.text_width
    text_rect := sdl.Rect { fbox.pos.x, fbox.pos.y, w, fbox.size.y}
    sdl.RenderCopy(renderer, fbox.texture, nil, &text_rect)
}

function_box_update :: proc(fbox: ^FunctionBox, renderer: ^sdl.Renderer, font: ^ttf.Font) {
    if fbox.texture != nil {
        sdl.DestroyTexture(fbox.texture)
    }
    text: cstring
    if strings.builder_len(fbox.text) > 0 {
        text = strings.to_cstring(&fbox.text)
    } else {
        text = " "
    }
    surface := ttf.RenderText_Solid(font, text, {0,0,0,255})
    fbox.texture = sdl.CreateTextureFromSurface(renderer, surface)
    fbox.text_width = surface.w
    sdl.FreeSurface(surface)
}
