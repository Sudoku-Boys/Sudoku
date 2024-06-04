const std = @import("std");

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
            var b = board.Board(k, n, layout, .HEAP).init(&self.allocator);
            const ValueType = @TypeOf(b).Storage.ValueType;

            for (0..str.len) |i| {
                const char = str[i];

                switch (char) {
                    '.' => b.set(.{ .i = i / b.size, .j = i % b.size }, 0),
                    else => {
                        // value is u8, make into ValueType by casting
                        const val: ValueType = @as(ValueType, @intCast(char - '0'));

                        b.set(.{ .i = i / b.size, .j = i % b.size }, val);
                    },
                }
            }

            return b;
        }

        pub fn into(self: *Self, b: anytype) ![]u8 {
            var result = std.ArrayList(u8).init(self.allocator);

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

// test "9x9 Stencil" {
//     const stencil = ".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....";
//     var alloc = std.testing.allocator;
//     var sudoku = from_stencil(stencil, 3, 3, .BITFIELD, &alloc);
//     defer sudoku.deinit();
//
//     const stencil_res = to_stencil(sudoku, &alloc);
//     try std.testing.expect(std.mem.eql(u8, stencil_res, stencil));
//     alloc.free(stencil_res);
// }

/// Semi-colon format.
pub fn Custom(comptime k: u16, comptime n: u16, comptime layout: board.StorageLayout) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .allocator = allocator };
        }

        pub fn from(self: *Self, str: []u8) board.Board(k, n, layout, .HEAP) {
            _ = self;
            _ = str;
        }

        pub fn into(self: *Self, b: anytype) []u8 {
            _ = self;
            _ = b;
            return "";
        }
    };
}
