const std = @import("std");
const system = @import("system.zig");
const World = @import("World.zig");

pub fn itemPointee(comptime T: type) ?type {
    switch (@typeInfo(T)) {
        .Pointer => |pointer| {
            if (pointer.is_const) return null;
            if (pointer.size != .One) return null;

            return pointer.child;
        },
        else => return null,
    }
}

pub const Error = error{
    ResourceNotFound,
};

pub fn Res(comptime T: type) type {
    const Pointee = itemPointee(T);

    const access_kind = if (Pointee != null) .Write else .Read;
    const Resource = Pointee orelse T;

    return struct {
        const Self = @This();

        item: T,

        pub const ACCESS: []const system.Access = &.{
            system.Access.init(Resource, access_kind, .Resource),
        };

        pub fn systemFetch(world: *World) !Self {
            const item = if (Pointee) |P| world.getResourcePtr(P) else world.getResource(T);

            return .{
                .item = item orelse return error.ResourceNotFound,
            };
        }
    };
}
