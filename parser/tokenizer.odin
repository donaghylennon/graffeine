package parser

import "core:unicode/utf8"

TokenKind :: enum {
    Invalid,
    Ident,
    Number,
    OpenParen,
    CloseParen,
    Plus,
    Minus,
    Mul,
    Div,
    Pow,
    EOF
}

Token :: struct {
    kind: TokenKind,
    text: string
}

Tokenizer :: struct {
    data: string,
    src_pos: int,
    rune: rune,
    token_pos: int,
    token_width: int
}

tokenizer_init :: proc(tokenizer: ^Tokenizer, data: string) {
    tokenizer.data = data
    tokenizer.src_pos = -1
    next_rune(tokenizer)
}

next_rune :: proc(tokenizer: ^Tokenizer) -> rune {
    tokenizer.src_pos += 1
    if tokenizer.src_pos >= len(tokenizer.data) {
        tokenizer.src_pos = len(tokenizer.data)
        tokenizer.rune = utf8.RUNE_EOF
    } else {
        tokenizer.rune = rune(tokenizer.data[tokenizer.src_pos])
    }
    if tokenizer.rune >= utf8.RUNE_SELF {
        panic("Non ascii text entered")
    }
    return tokenizer.rune
}

skip_whitespace :: proc(tokenizer: ^Tokenizer) {
    end := false
    for !end && tokenizer.src_pos < len(tokenizer.data) {
        switch tokenizer.rune {
            case ' ', '\t', '\r', '\f':
                next_rune(tokenizer)
            case:
                end = true
        }
    }
}

import "core:fmt"
get_token :: proc(tokenizer: ^Tokenizer) -> Token {
    token := Token{ .Invalid, "" }
    
    skip_whitespace(tokenizer)

    token_pos := tokenizer.src_pos
    current_rune := tokenizer.rune
    next_rune(tokenizer)

    switch current_rune {
    case 'A'..='Z', 'a'..='z', '_':
        token.kind = .Ident
        end := false
        for !end && tokenizer.src_pos < len(tokenizer.data) {
            switch tokenizer.rune {
            case 'A'..='Z', 'a'..='z', '_':
                next_rune(tokenizer)
            case:
                end = true
            }
        }
    case '0'..='9':
        token.kind = .Number
        end := false
        for !end && tokenizer.src_pos < len(tokenizer.data) {
            switch tokenizer.rune {
            case '0'..='9':
                next_rune(tokenizer)
            case:
                end = true
            }
        }
    case '(': token.kind = .OpenParen
    case ')': token.kind = .CloseParen
    case '+': token.kind = .Plus
    case '-': token.kind = .Minus
    case '*': token.kind = .Mul
    case '/': token.kind = .Div
    case '^': token.kind = .Pow
    case utf8.RUNE_EOF:
        token.kind = .EOF
    case:
        return token
    }

    token.text = tokenizer.data[token_pos:tokenizer.src_pos]

    return token
}
