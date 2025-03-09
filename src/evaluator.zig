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
        try self.variables.put(name, value);
    }
    
    pub fn get(self: *Environment, name: []const u8) ?Value {
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
                self.env.set(node.value.?, Value.init_function(node)) catch {
                    // Handle potential allocation error
                    return Value.init_null();
                };
                return Value.init_function(node);
            },
            NodeType.Call => {
                const func_node = node.left.?;
                const func_name = func_node.value.?;
                
                // Evaluate function arguments
                var args = std.ArrayList(Value).init(self.allocator);
                defer args.deinit();
                
                if (node.args) |call_args| {
                    for (call_args) |arg_node| {
                        const arg_value = try self.eval(arg_node);
                        args.append(arg_value) catch {
                            // Handle potential allocation error
                            return Value.init_null();
                        };
                    }
                }
                
                // Get function from environment
                if (self.env.get(func_name)) |func_value| {
                    if (func_value.vtype == ValueType.Function and func_value.function != null) {
                        return try self.eval_function(func_value.function.?, args.items);
                    }
                    if (func_value.vtype == ValueType.BuiltinFunction and func_value.builtin_fn != null) {
                        return func_value.builtin_fn.?(args.items, self.allocator) catch {
                            // Handle potential builtin function errors
                            return Value.init_null();
                        };
                    }
                    return EvalError.NotAFunction;
                }
                
                return EvalError.FunctionNotFound;
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
    
    // In the eval_function method, make sure the environment is correctly set up
    pub fn eval_function(self: *Evaluator, func_node: *Node, args: []Value) EvalError!Value {
        if (func_node.ntype != NodeType.Function) {
            return EvalError.NotAFunction;
        }
        
        // Create a new environment with the function's parent environment
        var func_env = Environment.init_with_outer(self.env, self.allocator);
        defer func_env.deinit();
        
        // Bind arguments to parameter names
        if (func_node.args) |params| {
            for (params, 0..) |param, i| {
                if (i >= args.len) {
                    break; // Not enough arguments provided
                }
                
                func_env.set(param.value.?, args[i]) catch {
                    return EvalError.FunctionCallError;
                };
            }
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
