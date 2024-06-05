/// Allows to parse an ascii integer stream of known length into a single number.
const std = @import("std");
const Self = @This();

value: usize,
weight: usize,

pub fn init() Self {
    return Self{
        .value = 0,
        .weight = 0,
    };
}

pub fn updateFromAscii(self: *Self, value: u8) void {
    std.debug.assert(value >= '0' and value <= '9');
    self.update(value - '0');
}

pub fn update(self: *Self, ordinal: usize) void {
    self.value += ordinal * std.math.pow(usize, 10, self.weight);
    self.weight += 1;
}

/// Completes the parsing and returns the final value.
/// Also resets the state of the parser.
pub fn finish(self: *Self) usize {
    var result = 0;

    // Reverse the weight to get the actual value.
    while (self.weight > 1) {
        result = result * 10 + self.value % 10;
        self.value /= 10;
        self.weight -= 1;
    }

    // Ensure that the value is zeroed out.
    std.debug.assert(self.value == 0);
    std.debug.assert(self.weight == 0);

    return result;
}
