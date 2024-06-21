const std = @import("std");
const naive = @import("solvers/naive.zig");
const basic = @import("solvers/basic.zig");
const mrv = @import("solvers/mrv.zig");
const wfc = @import("solvers/wfc.zig");

pub const Solvers = enum { NAIVE, BASIC, MRV, WFC };

const Self = @This();

fn assert_is_ptr(any: anytype) void {
    switch (@typeInfo(@TypeOf(any))) {
        .Pointer => {},
        else => @compileError("Expected pointer type"),
    }
}

/// TODOs:
/// - Add uniqueness / multiple solution handeling
/// - Prevent infinite loops etc
///
///
pub fn solve(solver: Solvers, sudoku: anytype, allocator: std.mem.Allocator) !bool {
    // Solve takes a pointer reference, as it needs to modify the sudoku in place.
    assert_is_ptr(sudoku);

    return switch (solver) {
        .NAIVE => naive.init().solve(sudoku),
        .BASIC => basic.init().solve(sudoku),
        .MRV => {
            var s = mrv.init(allocator);
            defer s.deinit();
            return s.solve(sudoku);
        },
        .WFC => {
            return wfc.WaveFunctionCollapse(@TypeOf(sudoku.*)).init().solve(sudoku, allocator);
        },
    };
}

test "Backtrack MRV solve" {
    var allocator = std.testing.allocator;

    const puzzle = ".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....";
    var parser = @import("parse.zig").Stencil(3, 3).init(allocator);
    var board = parser.from(puzzle);
    defer board.deinit();

    const has_solution = try solve(.MRV, &board, allocator);

    try std.testing.expect(has_solution);

    const expected = "938541762625379841147862935512796483863254197794138256459627318371485629286913574";
    const result = try parser.into(board);
    defer allocator.free(result);

    try std.testing.expect(std.mem.eql(u8, result, expected));
}


test "WFC Solve" {
    var allocator = std.testing.allocator;

    const puzzle = ".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....";
    var parser = @import("parse.zig").Stencil(3, 3).init(allocator);
    var board = parser.from(puzzle);
    defer board.deinit();

    const has_solution = try solve(.WFC, &board, allocator);

    try std.testing.expect(has_solution);

    const expected = "938541762625379841147862935512796483863254197794138256459627318371485629286913574";
    const result = try parser.into(board);
    defer allocator.free(result);

    try std.testing.expect(std.mem.eql(u8, result, expected));
}
