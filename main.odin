package main

import "core:strings"

import "render"
import "parser"

winsize : [2]i32 : { 1900, 1000 }
gridsize : [2]i32 : winsize
grid_interval :: f32(1)

main :: proc() {
    render.init()
    defer render.quit()

    window := render.create_window(winsize, pos={-1, -1}, zoom=50)
    defer render.destroy_window(&window)

    ast, ok := parser.parse("x^2")

    sidebar := &window.sidebar

    asts := make([dynamic]parser.Expr)
    defer delete(asts)
    defer for ast in asts do parser.destroy_ast(ast)
    append(&asts, ast)


    fps :: 60
    frame_time := 1/f64(fps)


    last_frame_time := render.get_time()
    for !window.should_close {
        time := render.get_time()
        dt := time - last_frame_time
        if (dt < frame_time) do continue
        last_frame_time = render.get_time()

        render.draw_window(window, asts)

        process_events(&window, &asts)
    }
}

destroy_asts :: proc(asts: [dynamic]parser.Expr) {
    for ast in asts {
        parser.destroy_ast(ast)
    }
}
