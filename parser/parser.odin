package parser

import "core:strconv"
import "core:fmt"

Expr :: union {
    FunctionCall,
    ArithmeticExpr,
    Var,
    Constant
}

Var :: struct {
    name: Ident
}

Constant :: distinct int

FunctionCall :: struct {
    name: Ident,
    arg: ^Expr
}

ArithmeticExpr :: struct {
    primary_operand: ^Expr,
    operator: ArithmeticOp,
    secondary_operand: ^Expr
}

ArithmeticOp :: enum {
    PLUS,
    MINUS,
    MUL,
    DIV,
    POW
}

Ident :: distinct string

Parser :: struct {
    tokenizer: ^Tokenizer,
    prev: Token,
    cur: Token
}

next :: proc(parser: ^Parser) -> Token {
    token := get_token(parser.tokenizer)
    parser.prev, parser.cur = parser.cur, token
    return parser.prev
}

peek :: proc(parser: ^Parser) -> TokenKind {
    return parser.cur.kind
}

parse_constant :: proc(parser: ^Parser) -> (expr: Expr, ok: bool) {
    token := expect(parser, .Number) or_return

    return Constant(strconv.atoi(token.text)), true
}

parse_ident :: proc(parser: ^Parser) -> (parse_ident: Ident, ok: bool) {
    token := expect(parser, .Ident) or_return

    return Ident(token.text), true
}

parse_var :: proc(parser: ^Parser) -> (expr: Expr, ok: bool) {
    ident := parse_ident(parser) or_return

    if peek(parser) == .OpenParen {
        next(parser)
        if !(peek(parser) == .CloseParen) {
            expr = parse_expr(parser) or_return
        }
        expect(parser, .CloseParen) or_return
        return FunctionCall { ident, new_clone(expr) }, true
    }

    return Var{ ident }, true
}

parse_primary :: proc(parser: ^Parser) -> (expr: Expr, ok: bool) {
    #partial switch peek(parser) {
        case .Ident:
            expr = parse_var(parser) or_return
        case .OpenParen:
            next(parser)
            expr = parse_expr(parser) or_return
            expect(parser, .CloseParen)
        case .Number:
            expr = parse_constant(parser) or_return
    }

    return expr, true
}

parse_power :: proc(parser: ^Parser) -> (expr: Expr, ok: bool) {
    expr = parse_primary(parser) or_return

    exponent: Expr
    for peek(parser) == .Pow {
        next(parser)
        op := ArithmeticOp.POW
        exponent = parse_primary(parser) or_return
        expr = ArithmeticExpr { new_clone(expr), op, new_clone(exponent) }
    }

    return expr, true
}

parse_factor :: proc(parser: ^Parser) -> (expr: Expr, ok: bool) {
    expr = parse_power(parser) or_return

    operand: Expr
    for peek(parser) == .Mul || peek(parser) == .Div {
        op_tk := next(parser)
        op := op_tk.kind == .Mul ? ArithmeticOp.MUL : ArithmeticOp.DIV
        operand = parse_power(parser) or_return
        expr = ArithmeticExpr { new_clone(expr), op, new_clone(operand) }
    }

    return expr, true
}

parse_sum :: proc(parser: ^Parser) -> (expr: Expr, ok: bool) {
    expr = parse_factor(parser) or_return

    operand: Expr
    for peek(parser) == .Plus || peek(parser) == .Minus {
        op_tk := next(parser)
        op := op_tk.kind == .Plus ? ArithmeticOp.PLUS : ArithmeticOp.MINUS
        operand = parse_factor(parser) or_return
        expr = ArithmeticExpr { new_clone(expr), op, new_clone(operand) }
    }

    return expr, true
}

parse_expr :: proc(parser: ^Parser) -> (expr: Expr, ok: bool) {
    return parse_sum(parser)
}

expect :: proc(parser: ^Parser, kind: TokenKind) -> (Token, bool) {
    token := next(parser)
    if token.kind != kind {
        return token, false
    }
    return token, true
}

print_ast :: proc(ast: Expr, level: int = 0) {
    indent :: proc(level: int) {
        for i:=0; i < level; i+=1 {
            fmt.print("\t")
        }
    }
    switch expr in ast {
        case FunctionCall:
            indent(level)
            fmt.printfln("FunctionCall: name: %v", expr.name)
            indent(level)
            fmt.print("arg: ")
            if expr.arg != nil {
                print_ast(expr.arg^, level+1)
            }
        case ArithmeticExpr:
            indent(level)
            fmt.printfln("ArithmeticExpr: op: %v", expr.operator)
            if expr.primary_operand != nil {
                print_ast(expr.primary_operand^, level+1)
            }
            if expr.secondary_operand != nil {
                print_ast(expr.secondary_operand^, level+1)
            }
        case Var:
            indent(level)
            fmt.printfln("Var: name: %v", expr.name)
        case Constant:
            indent(level)
            fmt.printfln("Constant: value: %v", expr)
    }
}

parse :: proc(input: string) -> (expr: Expr, ok: bool) {
    tokenizer: Tokenizer
    parser: Parser
    parser.tokenizer = &tokenizer
    tokenizer_init(&tokenizer, input)
    next(&parser)
    return parse_expr(&parser)
}

destroy_ast :: proc(ast: Expr) {
    switch expr in ast {
        case FunctionCall:
            if expr.arg != nil {
                destroy_ast(expr.arg^)
                free(expr.arg)
            }
        case ArithmeticExpr:
            if expr.primary_operand != nil {
                destroy_ast(expr.primary_operand^)
                free(expr.primary_operand)
            }
            if expr.secondary_operand != nil {
                destroy_ast(expr.secondary_operand^)
                free(expr.secondary_operand)
            }
        case Var:
        case Constant:
    }
}
