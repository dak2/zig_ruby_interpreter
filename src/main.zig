const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const NodeType = @import("ast.zig").NodeType;
const Node = @import("ast.zig").Node;
const Evaluator = @import("evaluator.zig").Evaluator;
const Environment = @import("evaluator.zig").Environment;
const Value = @import("evaluator.zig").Value;
const ValueType = @import("evaluator.zig").ValueType;

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
        NodeType.Function => {
            std.debug.print("Function: {s}\n", .{node.value.?});
            
            // Print arguments
            if (node.args) |args| {
                indent = 0;
                while (indent < depth + 1) : (indent += 1) {
                    std.debug.print("  ", .{});
                }
                std.debug.print("Arguments:\n", .{});
                
                for (args) |arg| {
                    print_ast(arg, depth + 2);
                }
            }
            
            // Print function body
            if (node.body) |body| {
                indent = 0;
                while (indent < depth + 1) : (indent += 1) {
                    std.debug.print("  ", .{});
                }
                std.debug.print("Body:\n", .{});
                
                for (body) |stmt| {
                    print_ast(stmt, depth + 2);
                }
            }
        },
        NodeType.Call => {
            std.debug.print("Call: ", .{});
            if (node.left) |func| {
                std.debug.print("{s}\n", .{func.value.?});
            } else {
                std.debug.print("<unknown>\n", .{});
            }
            
            // Print arguments
            if (node.args) |args| {
                indent = 0;
                while (indent < depth + 1) : (indent += 1) {
                    std.debug.print("  ", .{});
                }
                std.debug.print("Arguments:\n", .{});
                
                for (args) |arg| {
                    print_ast(arg, depth + 2);
                }
            }
        },
    }
}

fn print_value(value: Value) void {
    switch (value.vtype) {
        ValueType.Number => std.debug.print("{d}", .{value.number.?}),
        ValueType.String => std.debug.print("\"{s}\"", .{value.string.?}),
        ValueType.Boolean => std.debug.print("{}", .{value.boolean.?}),
        ValueType.Null => std.debug.print("nil", .{}),
        ValueType.Function => std.debug.print("<function: {s}>", .{value.function.?.value.?}),
        ValueType.BuiltinFunction => std.debug.print("<builtin function>", .{}),
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Create the environment
    var env = Environment.init(allocator);
    defer env.deinit();
    
    // Create the evaluator with built-ins
    var evaluator = try Evaluator.init_with_builtins(&env, allocator);

    // Interactive REPL loop
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Ruby REPL - Type 'exit' to quit\n", .{});
    
    var input_buffer = std.ArrayList(u8).init(allocator);
    defer input_buffer.deinit();
    
    var line_number: usize = 1;
    var in_multi_line = false;
    var open_blocks: usize = 0;
    
    while (true) {
        // Show appropriate prompt based on input state
        if (!in_multi_line) {
            try stdout.print("ruby> ", .{});
            line_number = 1;
            input_buffer.clearRetainingCapacity();
        } else {
            try stdout.print("ruby:{d}> ", .{line_number});
            line_number += 1;
        }
        
        var line_buffer: [1024]u8 = undefined;
        const read_result = stdin.readUntilDelimiter(&line_buffer, '\n') catch |err| {
            if (err == error.EndOfStream) {
                break; // EOF reached
            }
            try stdout.print("Error reading input: {}\n", .{err});
            continue;
        };

        // If read_result is a slice, use its length
        const bytes_read = if (@TypeOf(read_result) == []u8) read_result.len else read_result;
        const line = line_buffer[0..bytes_read];
        
        // Exit command
        if (!in_multi_line and (std.mem.eql(u8, line, "exit") or std.mem.eql(u8, line, "quit"))) {
            break;
        }
        
        // Add the line to our input buffer
        try input_buffer.appendSlice(line);
        try input_buffer.append('\n'); // Add newline
        
        // Check for block keywords that affect nesting
        if (std.mem.indexOf(u8, line, "def ") != null) {
            open_blocks += 1;
            in_multi_line = true;
        }
        if (std.mem.indexOf(u8, line, "end") != null) {
            if (open_blocks > 0) {
                open_blocks -= 1;
            }
        }
        
        // If we have a complete statement, evaluate it
        if (!in_multi_line or open_blocks == 0) {
            const source = input_buffer.items;
            
            // Skip empty input
            if (source.len == 0 or (source.len == 1 and source[0] == '\n')) {
                in_multi_line = false;
                continue;
            }
            
            // Lexer → Parser → AST → Evaluation
            const lexer = Lexer.init(source);
            var parser = Parser.init(lexer, allocator) catch |err| {
                try stdout.print("Parser initialization error: {}\n", .{err});
                in_multi_line = false;
                continue;
            };

            const ast = parser.parse_statement() catch |err| {
                if (in_multi_line) {
                    // If we're in multi-line mode and parsing fails, it might be incomplete
                    // Just continue collecting more input
                    continue;
                } else {
                    try stdout.print("Parsing error: {}\n", .{err});
                    in_multi_line = false;
                    continue;
                }
            };

            std.debug.print("\n=== AST ===\n", .{});
            print_ast(ast, 0);

            // Successfully parsed, evaluate it
            const result = evaluator.eval(ast) catch |err| {
                try stdout.print("Evaluation error: {}\n", .{err});
                in_multi_line = false;
                continue;
            };
            
            // Print the result in IRB style
            try stdout.print("=> ", .{});
            print_value(result);
            try stdout.print("\n", .{});
            
            // Reset for next input
            in_multi_line = false;
        }
    }
}
