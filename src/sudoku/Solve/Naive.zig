const std = @import("std");
const Sudoku = @import("sudoku.zig");

pub const SolverType = enum { BASIC, NAIVE, SIMD }; //These are placeholders until actual solvers are implemented

// This gets stuck on a lot of solutions, taken from here https://www.geeksforgeeks.org/sudoku-backtracking-7/.
// TODO generalize sudoku struct more.
pub fn naive_solve(s: *Sudoku.Sudoku(3, 3, .BITFIELD, .HEAP), row: usize, col: usize) bool {
    if (row == s.size and col == 0) {
        return true;
    }
    if (col == s.size) {
        return naive_solve(s, row + 1, 0);
    }

    const current_coordinate = .{ .i = row, .j = col };

    if (s.get(current_coordinate) > 0) {
        return naive_solve(s, row, col + 1);
    }

    for (1..(s.size + 1)) |i| {
        const v = @as(Sudoku.SudokuValueRangeType(3, 3), @intCast(i));

        if (s.is_valid_then_set(current_coordinate, v)) {
            if (naive_solve(s, row, col + 1)) {
                return true;
            }
        }

        s.set(current_coordinate, 0);
    }

    return false;
}
