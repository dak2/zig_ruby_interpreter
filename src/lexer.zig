const std = @import("std");

pub const TokenType = enum {
    Number,
    Identifier,
    Operator,
    Assign,
    LParen,
    RParen,
    Keyword,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,

    pub fn init(input: []const u8,) Lexer {
        return Lexer{
            .input = input,
        };
    }

    fn get_string(self: *Lexer) ?u8 {
        if (self.position >= self.input.len) return null;
        return self.input[self.position];
    }

    fn consume(self: *Lexer) void {
        self.position += 1;
    }

    pub fn next_token(self: *Lexer) ?Token {
        while (self.get_string()) |c| {
            switch (c) {
                ' ', '\t', '\n' => {
                    self.consume();
                },
                '0'...'9' => {
                    return self.read_number();
                },
                'a'...'z', 'A'...'Z', '_' => {
                    return self.read_identifier();
                },
                '+', '-', '*', '/', ',' => {
                    self.consume();
                    return Token{ .type = TokenType.Operator, .value = self.input[self.position - 1 .. self.position] };
                },
                '=' => {
                    self.consume();
                    return Token{ .type = TokenType.Assign, .value = "=" };
                },
                '(' => {
                    self.consume();
                    return Token{ .type = TokenType.LParen, .value = "(" };
                },
                ')' => {
                    self.consume();
                    return Token{ .type = TokenType.RParen, .value = ")" };
                },
                else => {
                    return null;
                },
            }
        }
        return Token{ .type = TokenType.EOF, .value = "" };
    }

    fn read_number(self: *Lexer) Token {
        const start = self.position;
        while (self.get_string()) |c| {
            if (c < '0' or c > '9') break;
            self.consume();
        }
        return Token{ .type = TokenType.Number, .value = self.input[start..self.position] };
    }

    fn read_identifier(self: *Lexer) Token {
        const start = self.position;
        while (self.get_string()) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') break;
            self.consume();
        }
        const ident = self.input[start..self.position];

        if (std.mem.eql(u8, ident, "def") or
            std.mem.eql(u8, ident, "end") or
            std.mem.eql(u8, ident, "if") or
            std.mem.eql(u8, ident, "while")) {
            return Token{ .type = TokenType.Keyword, .value = ident };
        }
        return Token{ .type = TokenType.Identifier, .value = ident };
    }
};

test "Lexer parses simple Ruby code" {
    const source = "x = 10 + 2";

    var lexer = Lexer.init(source);

    const expected_tokens = [_]Token{
        Token{ .type = TokenType.Identifier, .value = "x" },
        Token{ .type = TokenType.Assign, .value = "=" },
        Token{ .type = TokenType.Number, .value = "10" },
        Token{ .type = TokenType.Operator, .value = "+" },
        Token{ .type = TokenType.Number, .value = "2" },
        Token{ .type = TokenType.EOF, .value = "" },
    };

    var i: usize = 0;
    while (lexer.next_token()) |token| {
        try std.testing.expectEqual(expected_tokens[i].type, token.type);
        try std.testing.expectEqualSlices(u8, expected_tokens[i].value, token.value);
        if (token.type == TokenType.EOF) break;
        i += 1;
    }
}

test "Lexer handles keywords" {
    const source = "def my_func end";

    var lexer = Lexer.init(source);

    const expected_tokens = [_]Token{
        Token{ .type = TokenType.Keyword, .value = "def" },
        Token{ .type = TokenType.Identifier, .value = "my_func" },
        Token{ .type = TokenType.Keyword, .value = "end" },
        Token{ .type = TokenType.EOF, .value = "" },
    };

    var i: usize = 0;
    while (lexer.next_token()) |token| {
        try std.testing.expectEqual(expected_tokens[i].type, token.type);
        try std.testing.expectEqualSlices(u8, expected_tokens[i].value, token.value);
        if (token.type == TokenType.EOF) break;
        i += 1;
    }
}

test "Lexer handles parentheses and operators" {
    const source = "(1 + 2) * 3";

    var lexer = Lexer.init(source);

    const expected_tokens = [_]Token{
        Token{ .type = TokenType.LParen, .value = "(" },
        Token{ .type = TokenType.Number, .value = "1" },
        Token{ .type = TokenType.Operator, .value = "+" },
        Token{ .type = TokenType.Number, .value = "2" },
        Token{ .type = TokenType.RParen, .value = ")" },
        Token{ .type = TokenType.Operator, .value = "*" },
        Token{ .type = TokenType.Number, .value = "3" },
        Token{ .type = TokenType.EOF, .value = "" },
    };

    var i: usize = 0;
    while (lexer.next_token()) |token| {
        try std.testing.expectEqual(expected_tokens[i].type, token.type);
        try std.testing.expectEqualSlices(u8, expected_tokens[i].value, token.value);
        if (token.type == TokenType.EOF) break;
        i += 1;
    }
}
