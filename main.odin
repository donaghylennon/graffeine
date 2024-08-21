package main

import "core:math"
import "core:math/linalg"
import sdl "vendor:sdl2"

winsize : [2]i32 : { 800, 600 }
gridsize : [2]i32 : winsize

Window :: struct {
    pos: [2]f32,
    size: [2]i32,
    zoom: f32
}

main :: proc() {
    sdl.Init(sdl.INIT_VIDEO | sdl.INIT_EVENTS)

    win := sdl.CreateWindow("Graffeine", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, winsize.x, winsize.y, sdl.WINDOW_SHOWN)
    defer sdl.DestroyWindow(win)

    renderer := sdl.CreateRenderer(win, -1, sdl.RENDERER_ACCELERATED)
    defer sdl.DestroyRenderer(renderer)


    rect := sdl.Rect {0, 0, 40, 30}
    vel := [2]f64 { 200, 200 }
    color := [4]u8 { 255, 255, 255, 255 }


    window := Window {
        pos  = {-1, -1},
        size = winsize,
        zoom = 100
    }


    fps :: 60
    frame_time := 1/f64(fps)

    get_time :: proc() -> f64 { return f64(sdl.GetPerformanceCounter()) / f64(sdl.GetPerformanceFrequency()) }

    last_frame_time := get_time()
    done := false
    for !done {
        time := get_time()
        dt := time - last_frame_time
        if (dt < frame_time) do continue
        last_frame_time = get_time()

        sdl.SetRenderDrawColor(renderer, 255, 255, 255, 255)
        sdl.RenderClear(renderer)

        sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
        draw_grid(renderer, window, 1)
        sdl.SetRenderDrawColor(renderer, 225, 20, 30, 255)
        draw_sine(renderer, window)


        sdl.RenderPresent(renderer)


        e: sdl.Event
        for sdl.PollEvent(&e) {
            #partial switch e.type {
                case .QUIT:
                    done = true
                case .KEYDOWN:
                    #partial switch e.key.keysym.sym {
                        case .Q:
                            done = true
                    }
            }
        }
    }

    sdl.Quit()
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
    end : [2]f32 = window.pos + linalg.to_f32(window.size)/window.zoom
    range : [2]f32 = end - window.pos
    prev_screen_fx := window.pos.y
    for screen_x in 0..<window.size.x {
        x := window.pos.x + f32(screen_x)/window.zoom
        fx := math.sin(x)
        screen_fx := (fx - window.pos.y) * window.zoom
        sdl.RenderDrawLineF(renderer, f32(screen_x-1), f32(window.size.y) - prev_screen_fx, f32(screen_x), f32(window.size.y) - screen_fx)

        prev_screen_fx = screen_fx
    }
}

draw_grid :: proc(renderer: ^sdl.Renderer, window: Window, interval: f32) {
    num_lines := (linalg.to_f32(window.size)/interval)/window.zoom
    screen_interval := interval * window.zoom
    offset := linalg.ceil(window.pos) - window.pos
    for x in window.pos.x..<num_lines.x {
        x_line := i32(offset.x*window.zoom + x*screen_interval)
        sdl.RenderDrawLine(renderer, x_line, window.size.y, x_line, 0)
    }
    for y in window.pos.y..<num_lines.y {
        y_line := window.size.y - i32(offset.y*window.zoom + y*screen_interval)
        sdl.RenderDrawLine(renderer, window.size.x, y_line, 0, y_line)
    }
}
