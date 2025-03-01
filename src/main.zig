const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const NodeType = @import("ast.zig").NodeType;
const Node = @import("ast.zig").Node;

fn print_ast(node: *Node, depth: usize) void {
    var indent: usize = 0;
    while (indent < depth) : (indent += 1) {
        std.debug.print("  ", .{});
    }

    switch (node.ntype) {
        NodeType.Number => std.debug.print("Number: {s}\n", .{node.value.?}),
        NodeType.Identifier => std.debug.print("Identifier: {s}\n", .{node.value.?}),
        NodeType.BinaryExpression => {
            std.debug.print("BinaryExpression: {s}\n", .{node.value.?});
            print_ast(node.left.?, depth + 1);
            print_ast(node.right.?, depth + 1);
        },
        NodeType.Assign => {
            std.debug.print("Assign: {s}\n", .{node.value.?});
            print_ast(node.left.?, depth + 1);
        },
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    std.debug.print("Enter Ruby code: ", .{});
    var stdin = std.io.getStdIn().reader();
    var buffer: [256]u8 = undefined;
    const bytes_read = try stdin.read(&buffer);
    const source = buffer[0..bytes_read];

    // Lexer → Parser → AST
    const lexer = Lexer.init(source);
    var parser = try Parser.init(lexer, allocator);

    const ast = try parser.parse_statement();
    std.debug.print("\n=== AST ===\n", .{});
    print_ast(ast, 0);
}
