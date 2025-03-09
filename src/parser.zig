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

    // In your Parser struct, add:
    fn parse_primary(self: *Parser) anyerror!*Node {
        const expr = try self.parse_term();
        
        // Check if this is a function call
        if (self.current_token.type == TokenType.LParen) {
            return try self.parse_call(expr);
        }
        
        return expr;
    }

    fn parse_call(self: *Parser, func: *Node) !*Node {
        self.consume(); // Consume '('
        
        var args_list = std.ArrayList(*Node).init(self.allocator);
        defer args_list.deinit();
        
        if (self.current_token.type != TokenType.RParen) {
            // Parse arguments
            while (true) {
                const arg = try self.parse_expression();
                try args_list.append(arg);
                
                if (self.current_token.type == TokenType.Operator and 
                    std.mem.eql(u8, self.current_token.value, ",")) {
                    self.consume(); // Consume ','
                } else {
                    break;
                }
            }
        }
        
        if (self.current_token.type != TokenType.RParen) {
            return error.ExpectedClosingParen;
        }
        self.consume(); // Consume ')'
        
        const args_array = try self.allocator.dupe(*Node, args_list.items);
        return Node.init_call(func, args_array, self.allocator);
    }

    // Update parse_expression to use parse_primary instead of parse_term:
    pub fn parse_expression(self: *Parser) anyerror!*Node {
        var left = try self.parse_primary();
        
        while (self.current_token.type == TokenType.Operator) {
            const op = self.current_token.value;
            self.consume();
            const right = try self.parse_primary();
            left = try Node.init(NodeType.BinaryExpression, op, left, right, self.allocator);
        }
        return left;
    }

    fn parse_term(self: *Parser) anyerror!*Node {
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
        if (self.current_token.type == TokenType.Keyword and std.mem.eql(u8, self.current_token.value, "def")) {
            return self.parse_function();
        }

        if (self.current_token.type == TokenType.Identifier) {
            const ident = self.current_token.value;
            self.consume();
            if (self.current_token.type == TokenType.Assign) {
                self.consume();
                const expr = try self.parse_expression();
                return Node.init(NodeType.Assign, ident, expr, null, self.allocator);
            } else {
                const expr = try self.parse_expression();
                return expr;
            }
        }

        return self.parse_expression();
    }


    fn parse_function(self: *Parser) !*Node {
        self.consume(); // Consume 'def'
        
        if (self.current_token.type != TokenType.Identifier) {
            return error.ExpectedFunctionName;
        }

        const func_name = self.current_token.value;
        self.consume();

        var args_list = std.ArrayList(*Node).init(self.allocator);
        defer args_list.deinit();

        if (self.current_token.type == TokenType.LParen) {
            self.consume();

            while (self.current_token.type == TokenType.Identifier) {
                const arg = try Node.init(NodeType.Identifier, self.current_token.value, null, null, self.allocator);
                try args_list.append(arg);
                self.consume();
                
                if (self.current_token.type == TokenType.Operator and std.mem.eql(u8, self.current_token.value, ",")) {
                    self.consume();
                } else {
                    break;
                }
            }

            if (self.current_token.type != TokenType.RParen) {
                return error.ExpectedClosingParen;
            }
            self.consume();
        }

        var body_list = std.ArrayList(*Node).init(self.allocator);
        defer body_list.deinit();

        // Parse statements until we reach 'end'
        while (!(self.current_token.type == TokenType.Keyword and std.mem.eql(u8, self.current_token.value, "end"))) {
            const stmt = try self.parse_expression();
            try body_list.append(stmt);
            
            // If we've reached the end of the current expression, move to the next one
            if (self.current_token.type == TokenType.Operator and std.mem.eql(u8, self.current_token.value, ";")) {
                self.consume();
            }
        }
        self.consume(); // Consume 'end'

        // Create deep copies of the arrays for the node
        const args_array = try self.allocator.dupe(*Node, args_list.items);
        const body_array = try self.allocator.dupe(*Node, body_list.items);

        return Node.init_function(func_name, args_array, body_array, self.allocator);
    }
};

// test "Parser parses assignment" {
//     const gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();

//     const source = "x = 10 + 2";
//     const lexer = Lexer.init(source);
//     var parser = try Parser.init(lexer, allocator);

//     const ast = try parser.parse_statement();
//     try std.testing.expectEqual(NodeType.Assign, ast.ntype);
//     try std.testing.expectEqualSlices(u8, "x", ast.value.?);

//     try std.testing.expectEqual(NodeType.BinaryExpression, ast.left.?.ntype);
//     try std.testing.expectEqualSlices(u8, "+", ast.left.?.value.?);

//     try std.testing.expectEqual(NodeType.Number, ast.left.?.left.?.ntype);
//     try std.testing.expectEqualSlices(u8, "10", ast.left.?.left.?.value.?);

//     try std.testing.expectEqual(NodeType.Number, ast.left.?.right.?.ntype);
//     try std.testing.expectEqualSlices(u8, "2", ast.left.?.right.?.value.?);
// }

test "Parser parses def" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const source = "def test(x, y) x + y end";
    const lexer = Lexer.init(source);
    var parser = try Parser.init(lexer, allocator);

    const ast = try parser.parse_statement();
    try std.testing.expectEqual(NodeType.Function, ast.ntype);
    try std.testing.expectEqualSlices(u8, "test", ast.value.?);
    
    // Check that we have 2 arguments
    try std.testing.expectEqual(@as(usize, 2), ast.args.?.len);
    try std.testing.expectEqual(NodeType.Identifier, ast.args.?[0].ntype);
    try std.testing.expectEqualSlices(u8, "x", ast.args.?[0].value.?);
    try std.testing.expectEqual(NodeType.Identifier, ast.args.?[1].ntype);
    try std.testing.expectEqualSlices(u8, "y", ast.args.?[1].value.?);
    
    // Check the body contains the expression 'x + y'
    try std.testing.expectEqual(@as(usize, 1), ast.body.?.len);
    try std.testing.expectEqual(NodeType.BinaryExpression, ast.body.?[0].ntype);
    try std.testing.expectEqualSlices(u8, "+", ast.body.?[0].value.?);
}
