const std = @import("std");
const Self = @This();

i: usize,
j: usize,

pub fn equals(self: Self, other: Self) bool {
    return self.i == other.i and self.j == other.j;
}

pub fn random(max: usize, rng: *std.Random) Self {
    const row = rng.intRangeLessThan(usize, 0, max);
    const col = rng.intRangeLessThan(usize, 0, max);
    return Self{ .i = row, .j = col };
}
