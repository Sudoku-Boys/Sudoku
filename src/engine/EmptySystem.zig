//! A system that does nothing.

const World = @import("World.zig");

const EmptySystem = @This();

pub fn run(self: *EmptySystem, world: *World) !void {
    _ = world;
    _ = self;
}

pub fn apply(self: *EmptySystem, world: *World) !void {
    _ = world;
    _ = self;
}
