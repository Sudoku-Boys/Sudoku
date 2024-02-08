const std = @import("std");

const OpaqueMaterial = @This();

type_id: std.builtin.TypeId,
data: []u8,
alignment: u8,

pub fn init(allocator: std.mem.Allocator, material: anytype) !OpaqueMaterial {
    const T = @TypeOf(material);
    const type_id = std.meta.activeTag(@typeInfo(T));

    const data = try allocator.create(T);
    data.* = material;

    return .{
        .type_id = type_id,
        .data = std.mem.asBytes(data),
        .alignment = @alignOf(T),
    };
}

pub fn deinit(self: OpaqueMaterial, allocator: std.mem.Allocator) void {
    allocator.rawFree(
        self.data,
        @ctz(self.alignment),
        @returnAddress(),
    );
}

pub fn castPtr(self: OpaqueMaterial, comptime T: type) *T {
    return @ptrCast(@alignCast(self.data));
}

pub fn cast(self: OpaqueMaterial, comptime T: type) T {
    return self.castPtr(T).*;
}
