const std = @import("std");

pub const NodeType = enum {
    Number,
    Identifier,
    BinaryExpression,
    Assign,
};

pub const Node = struct {
    ntype: NodeType,
    value: ?[]const u8 = null,
    left: ?*Node = null,
    right: ?*Node = null,

    pub fn init(ntype: NodeType, value: ?[]const u8, left: ?*Node, right: ?*Node, allocator: std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        node.* = Node{ .ntype = ntype, .value = value, .left = left, .right = right };
        return node;
    }
};
