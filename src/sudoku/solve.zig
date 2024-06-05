const std = @import("std");
const naive = @import("solvers/naive.zig");
const basic = @import("solvers/basic.zig");
const simd = @import("solvers/simd.zig");

pub const Solvers = enum { NAIVE, BASIC, SIMD };

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
pub fn solve(solver: Solvers, sudoku: anytype) bool {
    // Solve takes a pointer reference, as it needs to modify the sudoku in place.
    assert_is_ptr(sudoku);

    return switch (solver) {
        .NAIVE => naive.init().solve(sudoku),
        .BASIC => basic.init().solve(sudoku),
        //.SIMD => simd.solve(sudoku),
        else => unreachable,
    };
}
