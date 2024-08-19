package main

import sdl "vendor:sdl2"

winsize : [2]i32 : { 800, 600 }
gridsize : [2]i32 : winsize

main :: proc() {
    sdl.Init(sdl.INIT_VIDEO | sdl.INIT_EVENTS)

    win := sdl.CreateWindow("Graffeine", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, winsize.x, winsize.y, sdl.WINDOW_SHOWN)
    defer sdl.DestroyWindow(win)

    renderer := sdl.CreateRenderer(win, -1, sdl.RENDERER_ACCELERATED)
    defer sdl.DestroyRenderer(renderer)


    rect := sdl.Rect {0, 0, 40, 30}
    vel := [2]f64 { 200, 200 }
    color := [4]u8 { 255, 255, 255, 255 }

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

        sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
        sdl.RenderClear(renderer)


        color.r = u8(f32(rect.x)/f32(winsize.x) * 255)
        color.g = u8(f32(rect.y)/f32(winsize.y) * 255)
        color.b = u8(f32(rect.x + rect.y)/f32(winsize.x+winsize.y) * 255)

        bounce_rect(renderer, &rect, &vel, color, dt)

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

bounce_rect :: proc(renderer: ^sdl.Renderer, rect: ^sdl.Rect, vel: ^[2]f64, color: [4]u8, dt: f64) {
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
