const std = @import("std");
const board = @import("board.zig");

pub fn from_stencil(stencil: []const u8, comptime k: u16, comptime n: u16, comptime S: board.StorageMemory, allocator: *std.mem.Allocator) board.Board(
    k,
    n,
    S,
    .HEAP,
) {
    const SudokuT = board.Board(k, n, S, .HEAP);
    const ValueRangeType = SudokuT.Storage.ValueType;

    var s = SudokuT.init(allocator);

    for (0..stencil.len) |i| {
        const value = stencil[i];

        switch (value) {
            '.' => s.set(.{ .i = i / s.size, .j = i % s.size }, 0),
            else => {
                // value is u8, make into ValueRangeType by casting
                const val: ValueRangeType = @as(ValueRangeType, @intCast(value - '0'));

                s.set(.{ .i = i / s.size, .j = i % s.size }, val);
            },
        }
    }

    return s;
}

pub fn to_stencil(s: anytype, allocator: *std.mem.Allocator) []u8 {
    const size = s.size;
    const stencil = allocator.alloc(u8, size * size) catch |err| {
        @panic(@errorName(err));
    };

    for (0..size * size) |i| {
        const value = s.get(.{ .i = i / size, .j = i % size });

        stencil[i] = if (value == 0) '.' else '0' + @as(u8, value);
    }

    return stencil;
}

test "9x9 Stencil" {
    const stencil = ".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....";
    var alloc = std.testing.allocator;
    var sudoku = from_stencil(stencil, 3, 3, .BITFIELD, &alloc);
    defer sudoku.deinit();

    const stencil_res = to_stencil(sudoku, &alloc);
    try std.testing.expect(std.mem.eql(u8, stencil_res, stencil));
    alloc.free(stencil_res);
}
