const std = @import("std");

const Camera = @import("Camera.zig");
const Object = @import("Object.zig");

const Scene = @This();

allocator: std.mem.Allocator,

camera: Camera,

objects: std.ArrayList(Object),

pub fn init(allocator: std.mem.Allocator) Scene {
    const objects = std.ArrayList(Object).init(allocator);

    return .{
        .allocator = allocator,

        .camera = .{},

        .objects = objects,
    };
}

pub fn deinit(self: Scene) void {
    self.objects.deinit();
}
