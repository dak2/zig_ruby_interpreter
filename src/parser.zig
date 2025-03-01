const std = @import("std");
const Token = @import("lexer.zig").Token;
const TokenType = @import("lexer.zig").TokenType;
const Lexer = @import("lexer.zig").Lexer;
const Node = @import("ast.zig").Node;
const NodeType = @import("ast.zig").NodeType;

pub const Parser = struct {
    lexer: Lexer,
    current_token: Token,
    allocator: std.mem.Allocator,

    pub fn init(lexer: Lexer, allocator: std.mem.Allocator) !Parser {
        var parser = Parser{ .lexer = lexer, .allocator = allocator, .current_token = undefined };
        parser.consume();
        return parser;
    }

    fn consume(self: *Parser) void {
        if (self.lexer.next_token()) |token| {
            self.current_token = token;
        } else {
            self.current_token = Token{ .type = TokenType.EOF, .value = "" };
        }
    }

    pub fn parse_expression(self: *Parser) anyerror!*Node {
        var left = try self.parse_term();

        while (self.current_token.type == TokenType.Operator) {
            const op = self.current_token.value;
            self.consume();
            const right = try self.parse_term();
            left = try Node.init(NodeType.BinaryExpression, op, left, right, self.allocator);
        }
        return left;
    }

    fn parse_term(self: *Parser) !*Node {
        switch (self.current_token.type) {
            TokenType.Number => {
                const value = self.current_token.value;
                self.consume();
                return Node.init(NodeType.Number, value, null, null, self.allocator);
            },
            TokenType.Identifier => {
                const value = self.current_token.value;
                self.consume();
                return Node.init(NodeType.Identifier, value, null, null, self.allocator);
            },
            TokenType.LParen => {
                self.consume();
                const expr = try self.parse_expression();
                if (self.current_token.type != TokenType.RParen) {
                    return error.ExpectedClosingParen;
                }
                self.consume();
                return expr;
            },
            else => return error.UnexpectedToken,
        }
    }

    pub fn parse_statement(self: *Parser) !*Node {
        if (self.current_token.type == TokenType.Identifier) {
            const ident = self.current_token.value;
            self.consume();
            if (self.current_token.type == TokenType.Assign) {
                self.consume();
                const expr = try self.parse_expression();
                return Node.init(NodeType.Assign, ident, expr, null, self.allocator);
            }
        }
        return error.InvalidStatement;
    }
};

test "Parser parses assignment" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const source = "x = 10 + 2";
    const lexer = Lexer.init(source);
    var parser = try Parser.init(lexer, allocator);

    const ast = try parser.parse_statement();
    try std.testing.expectEqual(NodeType.Assign, ast.ntype);
    try std.testing.expectEqualSlices(u8, "x", ast.value.?);

    try std.testing.expectEqual(NodeType.BinaryExpression, ast.left.?.ntype);
    try std.testing.expectEqualSlices(u8, "+", ast.left.?.value.?);

    try std.testing.expectEqual(NodeType.Number, ast.left.?.left.?.ntype);
    try std.testing.expectEqualSlices(u8, "10", ast.left.?.left.?.value.?);

    try std.testing.expectEqual(NodeType.Number, ast.left.?.right.?.ntype);
    try std.testing.expectEqualSlices(u8, "2", ast.left.?.right.?.value.?);
}
