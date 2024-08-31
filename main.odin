package main

import "core:strings"

import "render"
import "parser"

winsize : [2]i32 : { 1900, 1000 }
gridsize : [2]i32 : winsize
grid_interval :: f32(1)

min_zoom :: 5

main :: proc() {
    render.init()
    defer render.quit()

    window := render.create_window(winsize, pos={-1, -1}, zoom=50)
    defer render.destroy_window(&window)

    ast, ok := parser.parse("x^2")

    sidebar := render.sidebar_create(500, winsize)
    defer render.sidebar_destroy(sidebar)
    render.function_box_update(&sidebar.function_boxes[sidebar.selected], window)

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

        update_ast(&asts[sidebar.selected], &sidebar.function_boxes[sidebar.selected])

        render.clear(window)

        render.draw_grid(window, grid_interval)
        for ast in asts {
            render.draw_graph(window, ast)
        }
        render.draw_sidebar(window, sidebar)
        render.present(window)

        process_events(&window, &sidebar, &sidebar.function_boxes[sidebar.selected], &asts)
    }
}

update_ast :: proc(ast: ^parser.Expr, fbox: ^render.FunctionBox) {
    if !fbox.changed do return
    fbox.changed = false
    parser.destroy_ast(ast^)
    ok: bool
    ast^, ok = parser.parse(strings.to_string(fbox.text))
}

destroy_asts :: proc(asts: [dynamic]parser.Expr) {
    for ast in asts {
        parser.destroy_ast(ast)
    }
}
