const std = @import("std");

const World = @import("World.zig");

const Engine = @This();

world: World,

pub fn init(allocator: std.mem.Allocator) Engine {
    return .{
        .world = World.init(allocator),
    };
}

pub fn deinit(self: *Engine) void {
    self.world.deinit();
}
