const std = @import("std");
const Node = @import("ast.zig").Node;
const NodeType = @import("ast.zig").NodeType;

pub const ValueType = enum {
    Number,
    String,
    Boolean,
    Null,
    Function,
    BuiltinFunction,
};

const EvalError = error{
    TypeMismatch,
    DivisionByZero, 
    InvalidOperator,
    UnsupportedOperator,
    NotAFunction,
    FunctionNotFound,
    FunctionCallError,
    OutOfMemory,
};

pub const Value = struct {
    vtype: ValueType,
    number: ?f64 = null,
    string: ?[]const u8 = null,
    boolean: ?bool = null,
    function: ?*Node = null,
    builtin_fn: ?*const fn([]Value, std.mem.Allocator) anyerror!Value = null,
    
    pub fn init_number(num: f64) Value {
        return Value{
            .vtype = ValueType.Number,
            .number = num,
        };
    }
    
    pub fn init_string(str: []const u8) Value {
        return Value{
            .vtype = ValueType.String,
            .string = str,
        };
    }
    
    pub fn init_boolean(b: bool) Value {
        return Value{
            .vtype = ValueType.Boolean,
            .boolean = b,
        };
    }
    
    pub fn init_null() Value {
        return Value{
            .vtype = ValueType.Null,
        };
    }
    
    pub fn init_function(func: *Node) Value {
        return Value{
            .vtype = ValueType.Function,
            .function = func,
        };
    }
};

// Environment to track variables and their values
pub const Environment = struct {
    variables: std.StringHashMap(Value),
    outer: ?*Environment,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Environment {
        return Environment{
            .variables = std.StringHashMap(Value).init(allocator),
            .outer = null,
            .allocator = allocator,
        };
    }
    
    pub fn init_with_outer(outer: *Environment, allocator: std.mem.Allocator) Environment {
        return Environment{
            .variables = std.StringHashMap(Value).init(allocator),
            .outer = outer,
            .allocator = allocator,
        };
    }
    
    pub fn set(self: *Environment, name: []const u8, value: Value) !void {
        // Duplicate the string to ensure it has a stable lifetime
        const key_copy = try self.allocator.dupe(u8, name);
        
        // Use the duplicated string as the key
        try self.variables.put(key_copy, value);
    }

    pub fn get(self: *Environment, name: []const u8) ?Value {
        
        // Debug print all variables in the environment
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            const stored_key = entry.key_ptr.*;
            
            // Check if this key matches the one we're looking for
            if (std.mem.eql(u8, stored_key, name)) {
                return entry.value_ptr.*;
            }
        }
        
        // Use standard lookup (this should work if the hash function is correct)
        if (self.variables.get(name)) |value| {
            return value;
        }
        
        if (self.outer) |outer| {
            return outer.get(name);
        }
        
        return null;
    }
        
    pub fn deinit(self: *Environment) void {
        self.variables.deinit();
    }
};

fn puts_function(args: []Value, _: std.mem.Allocator) !Value {
    for (args) |arg| {
        switch (arg.vtype) {
            ValueType.String => std.debug.print("{s}\n", .{arg.string.?}),
            ValueType.Number => std.debug.print("{d}\n", .{arg.number.?}),
            ValueType.Boolean => std.debug.print("{}\n", .{arg.boolean.?}),
            ValueType.Null => std.debug.print("nil\n", .{}),
            ValueType.Function => std.debug.print("<function>\n", .{}),
            ValueType.BuiltinFunction => std.debug.print("<builtin-function>\n", .{}),
        }
    }
    return Value.init_null();
}

fn gets_function(_: []Value, allocator: std.mem.Allocator) !Value {
    var buffer: [1024]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    
    const read_result = stdin.readUntilDelimiter(&buffer, '\n') catch |err| {
        if (err == error.EndOfStream) {
            return Value.init_null(); // EOF reached
        }
        return err;
    };
    
    // If read_result is a slice, use its length
    const bytes_read = if (@TypeOf(read_result) == []u8) read_result.len else read_result;
    const slice = buffer[0..bytes_read];
    const input = try allocator.dupe(u8, slice);
    return Value.init_string(input);
}

pub const Evaluator = struct {
    env: *Environment,
    allocator: std.mem.Allocator,
    
    pub fn init(env: *Environment, allocator: std.mem.Allocator) Evaluator {
        return Evaluator{
            .env = env,
            .allocator = allocator,
        };
    }

    pub fn init_with_builtins(env: *Environment, allocator: std.mem.Allocator) !Evaluator {
        const evaluator = Evaluator.init(env, allocator);
        
        // Add some built-in functions
        try env.set("puts", Value{
            .vtype = ValueType.BuiltinFunction,
            .builtin_fn = puts_function,
        });
        
        try env.set("gets", Value{
            .vtype = ValueType.BuiltinFunction, 
            .builtin_fn = gets_function,
        });
        
        return evaluator;
    }
    
    pub fn eval(self: *Evaluator, node: *Node) EvalError!Value {
        switch (node.ntype) {
            NodeType.Number => {
                const num = std.fmt.parseFloat(f64, node.value.?) catch {
                    return EvalError.TypeMismatch;
                };
                return Value.init_number(num);
            },
            NodeType.Identifier => {
                if (self.env.get(node.value.?)) |value| {
                    return value;
                }
                return Value.init_null(); // Variable not found
            },
            NodeType.BinaryExpression => {
                return try self.eval_binary_expression(node);
            },
            NodeType.Assign => {
                const value = try self.eval(node.left.?);
                self.env.set(node.value.?, value) catch {
                    // Handle potential allocation error
                    return Value.init_null();
                };
                return value;
            },
            NodeType.Function => {
                // Store the function in the environment
                try self.env.set(node.value.?, Value.init_function(node));
                
                // Debug print to verify
                std.debug.print("Stored function: {s} in environment\n", .{node.value.?});
                
                return Value.init_function(node);
            },
            // In your eval method, in the NodeType.Call case:
            NodeType.Call => {
                const func_name = node.value.?;
                
                // Debug to verify the function name
                std.debug.print("Calling function: {s}\n", .{func_name});
                
                // Evaluate function arguments
                var args = std.ArrayList(Value).init(self.allocator);
                defer args.deinit();
                
                if (node.args) |call_args| {
                    for (call_args) |arg_node| {
                        const arg_value = try self.eval(arg_node);
                        try args.append(arg_value);
                    }
                }
                
                // Get function from environment
                if (self.env.get(func_name)) |func_value| {
                    
                    if (func_value.vtype == ValueType.Function and func_value.function != null) {
                        return try self.eval_function(func_value.function.?, args.items);
                    }
                    
                    if (func_value.vtype == ValueType.BuiltinFunction and func_value.builtin_fn != null) {
                        return func_value.builtin_fn.?(args.items, self.allocator) catch |err| {
                            std.debug.print("Built-in function error: {}\n", .{err});
                            return EvalError.FunctionCallError; // Convert any error to a known error type
                        };
                    }
                    
                    return error.NotAFunction;
                }
                
                return error.FunctionNotFound;
            },
        }
    }
    
    fn eval_binary_expression(self: *Evaluator, node: *Node) EvalError!Value {
        const left = try self.eval(node.left.?);
        const right = try self.eval(node.right.?);
        
        if (left.vtype != ValueType.Number or right.vtype != ValueType.Number) {
            // For simplicity, we'll only handle numeric operations for now
            return EvalError.TypeMismatch;
        }
        
        const op = node.value.?;
        if (op.len != 1) {
            return EvalError.InvalidOperator;
        }
        
        const left_val = left.number.?;
        const right_val = right.number.?;
        
        switch (op[0]) {
            '+' => return Value.init_number(left_val + right_val),
            '-' => return Value.init_number(left_val - right_val),
            '*' => return Value.init_number(left_val * right_val),
            '/' => {
                if (right_val == 0) {
                    return EvalError.DivisionByZero;
                }
                return Value.init_number(left_val / right_val);
            },
            else => return EvalError.UnsupportedOperator,
        }
    }
    
    pub fn eval_function(self: *Evaluator, func_node: *Node, args: []Value) EvalError!Value {
        // Create a mapping of parameter names to argument values
        var params_map = std.StringHashMap(Value).init(self.allocator);
        defer params_map.deinit();
        
        // Manually set parameters for now (quick fix)
        try params_map.put("x", args[0]);
        try params_map.put("y", args[1]);
        
        // Create a new environment with the function's parent environment
        var func_env = Environment.init_with_outer(self.env, self.allocator);
        defer func_env.deinit();
        
        // Add parameters to environment
        var it = params_map.iterator();
        while (it.next()) |entry| {
            try func_env.set(entry.key_ptr.*, entry.value_ptr.*);
        }
        
        // Create a new evaluator with the function's environment
        var func_evaluator = Evaluator{
            .env = &func_env,
            .allocator = self.allocator,
        };
        
        // Evaluate the function body with the new evaluator
        var result = Value.init_null();
        
        if (func_node.body) |body| {
            for (body) |stmt| {
                result = try func_evaluator.eval(stmt);
            }
        }
        
        return result;
    }
};
