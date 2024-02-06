const std = @import("std");

const Entity = @This();

pub const NULL_GEN = std.math.maxInt(u32);

index: u32,
generation: u32,

pub fn eq(self: Entity, other: Entity) bool {
    return self.index == other.index and self.generation == other.generation;
}
