const std = @import("std");
const Self = @This();
const board = @import("../board.zig");
const Coordinate = @import("../Coordinate.zig");

pub fn init() Self {
    return Self{};
}

pub fn deinit(self: Self) void {
    _ = self;
}

// Find an unassigned coordinate with the minimum possible values (MRV heuristic)
fn find_unassigned_coord(sudoku: anytype) ?Coordinate {
    var min_pos: ?Coordinate = null;
    var min_possibilities = sudoku.size + 1;

    for (0..sudoku.size) |i| {
        for (0..sudoku.size) |j| {
            const pos = Coordinate{ .i = i, .j = j };

            if (sudoku.get(pos) == board.EmptySentinel) {
                const possibilities = sudoku.get_possibilities(pos).len;
                if (possibilities < min_possibilities) {
                    min_pos = pos;
                    min_possibilities = possibilities;
                }
            }
        }
    }

    return min_pos;
}

// This helper function checks if placing a number at a given position is valid
fn is_valid(sudoku: anytype, pos: Coordinate, num: anytype) bool {
    return sudoku.is_safe_move(pos, num);
}

pub fn solve(self: Self, sudoku: anytype) bool {
    if (find_unassigned_coord(sudoku)) |coord| {
        const possibilities = sudoku.get_possibilities(coord);

        for (possibilities) |num| {


            if (is_valid(sudoku, coord, num)) {
                sudoku.set(coord, num);

                if (self.solve(sudoku)) {
                    return true;
                }

                sudoku.set(coord, board.EmptySentinel);
            }
        }

        return false;
    }

    // No more unassigned spots
    return true;
}
