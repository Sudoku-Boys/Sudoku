const std = @import("std");
// const Sudoku = @import("sudoku.zig");
// const Solvers = @import("solvers.zig");

const board = @import("board.zig");
const sudoku = @import("Sudoku.zig");

test "Wow" {
    const T = board.Board(3, 3, .MATRIX, .STACK);
    var b = T.init(null);
    const s = sudoku.Sudoku.init(&b);

    s.clear();
}

pub fn main() !void {
    //var optionalAllocator: std.mem.Allocator = std.heap.page_allocator;
    //
    //var s = Sudoku.from_stencil(".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....", 3, 3, .BITFIELD, &optionalAllocator);
    //
    //// var s = Sudoku.Sudoku(3, 1, .BITFIELD, .HEAP).init(&optionalAllocator);
    //defer s.deinit();
    //
    ////s.set_row(0, .{ 1, 2, 3 });
    ////s.set_row(1, .{ 2, 3, 1 });
    ////s.set_row(2, .{ 3, 1, 2 });
    //
    //s.set_row(0, .{ 3, 0, 6, 5, 0, 8, 4, 0, 0 });
    //s.set_row(1, .{ 5, 2, 0, 0, 0, 0, 0, 0, 0 });
    //s.set_row(2, .{ 0, 8, 7, 0, 0, 0, 0, 3, 1 });
    //s.set_row(3, .{ 0, 0, 3, 0, 1, 0, 0, 8, 0 });
    //s.set_row(4, .{ 9, 0, 0, 8, 6, 3, 0, 0, 5 });
    //s.set_row(5, .{ 0, 5, 0, 0, 9, 0, 6, 0, 0 });
    //s.set_row(6, .{ 1, 3, 0, 0, 0, 0, 2, 5, 0 });
    //s.set_row(7, .{ 0, 0, 0, 0, 0, 0, 0, 7, 4 });
    //s.set_row(8, .{ 0, 0, 5, 2, 0, 6, 3, 0, 0 });
    //
    //const writer = std.io.getStdOut().writer();
    //
    //_ = try s.display(writer);
    //
    //s.clear();
    //
    //_ = try s.display(writer);
    //
    //const time: u64 = @intCast(std.time.milliTimestamp());
    //var rng = std.rand.DefaultPrng.init(time);
    //var random = rng.random();
    //
    //s.fill_random_valid(1000, &random);
    //
    //_ = try s.display(writer);
    //
    //const solveable = Solvers.naive_solve(&s, 0, 0);
    //
    //_ = try s.display(writer);
    //
    //std.debug.print("Solveable: {}\n", .{solveable});
    //
    //std.debug.print("Grid count {d}\n", .{s.k * s.k});
    //
    //std.debug.print("As stencil {s}\n", .{Sudoku.to_stencil(s, &optionalAllocator)});
    //
    //const errors = try s.validate_all(optionalAllocator);
    //
    //std.debug.print("Row errors count: {d}\n", .{errors.get(.ROW).items.len});
    //std.debug.print("Column errors count: {d}\n", .{errors.get(.COLUMN).items.len});
    //std.debug.print("Grid errors count: {d}\n", .{errors.get(.GRID).items.len});
}
