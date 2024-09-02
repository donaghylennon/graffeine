# Graffeine

- Initially draw grid (0,0) at bottom left, grid lines at multiples of 10, cut
off at win size
- Then allow offsets (positive or negative), so bottom left can be any point
- Zooming in and out/scaling
    - Only need to draw what's on the screen, so loop through each x pixel and
    convert to location on real graph?
    - Any reason to get graph points first and then convert to screen?
- Scaling each axis independently

- UI to select a function
- Or type a function, allowing more complex functions, and parse this input

- Multiple graphs, different colors, custom colors
- Increase/decrease grid granularity based on zoom level
- Display tick numbers on axes
- Draw functions of y
- Multi-argument functions
- Variable definitions and value sliders

- Improve visuals:
    - Better text rendering
    - Thicker lines
    - Prettier UI elements
    - Click animations on UI elements

- Points/vectors and variables/expressions
- Radial functions/polar coords


## Function Parsing

expr := function-call | arithmetic | var | constant
var := name
constant := [1-9]+
function-call := name ( expr )
arithmetic := expr arithmetic-operator expr
arithmetic-operator := + | - | * | / | ^


expr := sum
sum := factor ( '+' | '-' factor )*
factor := power ( '*' | '/' power )*
power := primary ( '^' primary )*
primary := function-call | constant | expr
function-call := identifier ( '(' expr ')' )*
identifier := ( 'A'..'Z' | 'a'..'z' | '_' )+

## Seperating out UI

- Processing events on UI
    - window_process_click, window_process_keypress, etc.
    - need asts so function boxes can update them
    - could pass them in to the event processing functions, maybe as part of
    a bigger state struct
    - could have function boxes hold a reference to the ast but this would not
    help removing asts from list when closing box, not to mention these would be
    references to elements of a dynamic array
- State struct:
    - Name: State, Graph(maybe sub struct holding asts, color, etc.)
    -> GraphDisplay instead, Grid
    - dynamic array of asts
    - might make more sense to move state from Window to this struct:
        - sdl stuff to renderer struct
        - viewport info to state struct
        - Window then only contains UI elements
- Integrating UI with model (Asts/Graphs)

- When a function box's text changes we need to trigger a re-parse of the text
