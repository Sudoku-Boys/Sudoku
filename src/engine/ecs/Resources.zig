const std = @import("std");
const dynamic = @import("dynamic.zig");

const Resources = @This();

const Resource = struct {
    data: []u8,
    deinit: ?*const fn (*anyopaque) void,
};

resources: std.AutoHashMap(std.builtin.TypeId, Resource),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Resources {
    return Resources{
        .resources = std.AutoHashMap(std.builtin.TypeId, Resource).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Resources) void {
    var it = self.resources.valueIterator();
    while (it.next()) |resource| {
        if (resource.deinit) |deinitResource| {
            deinitResource(resource.data.ptr);
        }
    }

    self.resources.deinit();
}

fn ptrCast(comptime T: type, ptr: anytype) *T {
    return @ptrCast(@alignCast(ptr));
}

pub fn contains(self: *const Resources, comptime T: type) bool {
    const type_id = std.meta.activeTag(@typeInfo(T));

    return self.resources.contains(type_id);
}

pub fn add(self: *Resources, resource: anytype) !void {
    const T = @TypeOf(resource);
    const type_id = std.meta.activeTag(@typeInfo(T));

    if (self.resources.get(type_id)) |res| {
        if (res.deinit) |deinitResource| {
            deinitResource(res.data.ptr);
        }

        ptrCast(T, res.data).* = resource;

        return;
    }

    var bytes: []u8 = &.{};

    if (@sizeOf(T) > 0) {
        const data = try self.allocator.alloc(T, 1);
        data[0] = resource;

        bytes = std.mem.sliceAsBytes(data);
    }

    try self.resources.put(type_id, Resource{
        .data = bytes,
        .deinit = dynamic.deinitFn(T),
    });
}

pub fn get(self: *const Resources, comptime T: type) ?T {
    if (self.getPtr(T)) |ptr| {
        return ptr.*;
    }

    return null;
}

pub fn getPtr(self: *const Resources, comptime T: type) ?*T {
    const type_id = std.meta.activeTag(@typeInfo(T));

    if (self.resources.get(type_id)) |res| {
        return ptrCast(T, res.data);
    }

    return null;
}

pub fn remove(self: *Resources, comptime T: type) ?T {
    const type_id = std.meta.activeTag(@typeInfo(T));

    if (self.resources.get(type_id)) |res| {
        const data = ptrCast(T, res.data).*;

        self.allocator.free(res.data);
        _ = self.resources.remove(type_id);

        return data;
    }

    return null;
}
