const std = @import("std");
const Sudoku = @import("Sudoku.zig");

pub fn main() !void {
    const S = Sudoku.Sudoku(10, 1000, .MATRIX, .HEAP);

    var optionalAllocator: std.mem.Allocator = std.heap.page_allocator;

    var s = S.init(&optionalAllocator);
    defer s.deinit();

    std.debug.print("Size of board {}\n", .{s.size});

    _ = s.set(.{ .i = 99, .j = 99 }, 99);
}

test "Some test" {
    try std.testing.expect(Sudoku.SudokuMemory.HEAP != Sudoku.SudokuMemory.STACK);
}
