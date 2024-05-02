const std = @import("std");
const Sudoku = @import("sudoku.zig");

pub fn main() !void {
    var optionalAllocator: std.mem.Allocator = std.heap.page_allocator;

    var s = Sudoku.from_stencil(".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....", 3, 3, .MATRIX, &optionalAllocator);
    defer s.deinit();

    s.set(.{ .i = 1, .j = 1 }, 8);
    const writer = std.io.getStdOut().writer();

    s.set(.{ .i = 3, .j = 3 }, 9);
    s.set_grid(4, .{ 1, 2, 3, 4, 5, 6, 7, 8, 9 });

    std.debug.assert(s.validate(.GRID, 4) == null);

    _ = try s.display(writer);

    std.debug.print("As stencil {s}\n", .{Sudoku.to_stencil(s, &optionalAllocator)});

    const errors = try s.validate_all(optionalAllocator);

    std.debug.print("Row errors count: {d}\n", .{errors.get(.ROW).items.len});
    std.debug.print("Column errors count: {d}\n", .{errors.get(.COLUMN).items.len});
    std.debug.print("Grid errors count: {d}\n", .{errors.get(.GRID).items.len});
}

test "Test to include suduku.zig" {
    try std.testing.expect(Sudoku.SudokuMemory.HEAP != Sudoku.SudokuMemory.STACK);
}
