const std = @import("std");
const IntParser = @import("IntParser.zig");
const board = @import("board.zig");

/// Common "stencil" format.
/// .................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....
pub fn Stencil(comptime k: u16, comptime n: u16, comptime layout: board.StorageLayout) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .allocator = allocator };
        }

        pub fn from(self: *Self, str: []const u8) board.Board(k, n, layout, .HEAP) {
            var b = board.Board(k, n, layout, .HEAP).init(self.allocator);
            const ValueType = @TypeOf(b).Storage.ValueType;

            for (0..str.len) |i| {
                const char = str[i];
                const coord = .{ .i = i / b.size, .j = i % b.size };

                switch (char) {
                    '.' => b.set(coord, 0),
                    else => {
                        // value is u8, make into ValueType by casting
                        const val: ValueType = @as(ValueType, @intCast(char - '0'));

                        b.set(coord, val);
                    },
                }
            }

            return b;
        }

        pub fn into(self: *Self, b: anytype) ![]u8 {
            var result = std.ArrayList(u8).init(self.allocator);
            try result.ensureTotalCapacityPrecise(b.size * b.size);

            for (0..b.size * b.size) |i| {
                const cell = b.get(.{ .i = i / b.size, .j = i % b.size });

                if (cell == 0) {
                    _ = try result.append('.');
                } else {
                    // Only supports single digit values.
                    // Should still work since ascii haha.
                    _ = try result.append('0' + @as(u8, @intCast(cell)));
                }
            }

            return result.toOwnedSlice();
        }
    };
}

test "stencil" {
    const StencilFormat = Stencil(3, 3, .BITFIELD);
    const allocator = std.heap.page_allocator;
    var format = StencilFormat.init(allocator);

    const str = ".........1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91............";
    const b = format.from(str);

    const expected = ".........1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91............";
    const result = try format.into(b);

    try std.testing.expect(std.mem.eql(u8, result, expected));
}

/// Semi-colon format.
/// Needs an aditional step that parses the first line
/// That contains K and N values, this parses everything after that.
pub fn Custom(comptime k: u16, comptime n: u16, comptime layout: board.StorageLayout) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .allocator = allocator };
        }

        pub fn from(self: *Self, str: []u8) board.Board(k, n, layout, .HEAP) {
            var b = board.Board(k, n, layout, .HEAP).init(&self.allocator);
            const ValueType = @TypeOf(b).Storage.ValueType;

            var int_parser = IntParser.init();
            var coord: board.Coord = .{ .i = 0, .j = 0 };

            for (0..str.len) |i| {
                const char = str[i];

                switch (char) {
                    ';' => {
                        b.set(coord, @as(ValueType, @intCast(int_parser.finish())));
                        coord.i += 1;
                        coord.j = 0;
                    },
                    '\n' => {
                        b.set(coord, @as(ValueType, @intCast(int_parser.finish())));
                        coord.j += 1;
                    },
                    '.' => {},
                    else => {
                        // value is u8, make into ValueType by casting
                        int_parser.updateFromAscii(char);
                    },
                }
            }

            return b;
        }

        pub fn into(self: *Self, b: anytype) []u8 {
            _ = self;
            _ = b;
            return "";
        }
    };
}
