const std = @import("std");
const Sudoku = @import("Sudoku.zig");

test "Include sudoku.zig" {
    _ = Sudoku.AnySudoku.init(null);
}

pub fn main() !void {
    const S = Sudoku.Sudoku(10, 10, .MATRIX, .STACK);

    // var optionalAllocator: std.mem.Allocator = std.heap.page_allocator;

    //    std.debug.print("Sudoku: {}\n", .{@typeInfo(S)});

    var s = S.init(null);
    defer s.deinit();

    std.debug.print("Size of board {}\n", .{s.size});

    _ = s.set(.{ .i = 99, .j = 99 }, 99);
}
