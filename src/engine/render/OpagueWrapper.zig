const std = @import("std");

const OpaqueWrapper = @This();

type_id: std.builtin.TypeId,
data: []u8,
alignment: u8,

pub fn init(allocator: std.mem.Allocator, material: anytype) !OpaqueWrapper {
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

pub fn deinit(self: OpaqueWrapper, allocator: std.mem.Allocator) void {
    allocator.rawFree(
        self.data,
        @ctz(self.alignment),
        @returnAddress(),
    );
}

pub fn castPtr(self: OpaqueWrapper, comptime T: type) *T {
    return @ptrCast(@alignCast(self.data));
}

pub fn cast(self: OpaqueWrapper, comptime T: type) T {
    return self.castPtr(T).*;
}
