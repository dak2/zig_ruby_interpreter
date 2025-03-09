const std = @import("std");

pub const NodeType = enum {
    Number,
    Identifier,
    Function,
    BinaryExpression,
    Assign,
    Call
};

pub const Node = struct {
    ntype: NodeType,
    value: ?[]const u8 = null,
    left: ?*Node = null,
    right: ?*Node = null,
    args: ?[]*Node = null,
    body: ?[]*Node = null,

    pub fn init(ntype: NodeType, value: ?[]const u8, left: ?*Node, right: ?*Node, allocator: std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        node.* = Node{ .ntype = ntype, .value = value, .left = left, .right = right, .args = null, .body = null };
        return node;
    }

    pub fn init_function(name: []const u8, args: []*Node, body: []*Node, allocator: std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        
        // Create new arrays to own the data
        const args_copy = try allocator.alloc(*Node, args.len);
        std.mem.copyForwards(*Node, args_copy, args);
        
        const body_copy = try allocator.alloc(*Node, body.len);
        std.mem.copyForwards(*Node, body_copy, body);
        
        node.* = Node{ 
            .ntype = NodeType.Function, 
            .value = name, 
            .args = args_copy, 
            .body = body_copy,
            .left = null,
            .right = null
        };
        
        return node;
    }

    pub fn init_call(func: *Node, args: []*Node, allocator: std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        
        var args_copy = try allocator.alloc(*Node, args.len);
        for (args, 0..) |arg, i| {
            args_copy[i] = arg;
        }
        
        node.* = Node{
            .ntype = NodeType.Call,
            .left = func,  // Function to call
            .right = null,
            .args = args_copy, // Arguments to pass
            .body = null,
            .value = null,
        };
        
        return node;
    }
};
