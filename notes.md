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
