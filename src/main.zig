const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("lexer.zig").TokenType;
const Token = @import("lexer.zig").Token;

pub fn main() !void {
    const source = "x = 10 + 2";
    var lexer = Lexer.init(source);

    while (lexer.next_token()) |token| {
        if (token.type == TokenType.EOF) break;
        std.debug.print("Token: {s} ({s})\n", .{ @tagName(token.type), token.value });
    }
}
