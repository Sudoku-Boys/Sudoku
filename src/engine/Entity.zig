const std = @import("std");

const Entity = @This();

pub const MAX_GENERATIONS = std.math.maxInt(u32);

index: u32,
generation: u32,

pub fn init(index: u32) Entity {
    return .{
        .index = index,
        .generation = 0,
    };
}

pub fn eql(self: Entity, other: Entity) bool {
    return self.index == other.index and
        self.generation == other.generation;
}
