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

pub fn solve(self: Self, sudoku: anytype) !bool {
    return self.basic_solve(sudoku);
}

fn find_unassigned_coord(sudoku: anytype) ?Coordinate {
    for (0..sudoku.size) |i| {
        for (0..sudoku.size) |j| {
            const pos = Coordinate{ .i = i, .j = j };

            if (sudoku.get(pos) == board.EmptySentinel) {
                return pos;
            }
        }
    }

    return null;
}

fn basic_solve(self: Self, sudoku: anytype) bool {
    if (find_unassigned_coord(sudoku)) |coord| {
        for (1..(sudoku.size + 1)) |i| {
            const num = @as(@TypeOf(sudoku.*).Storage.ValueType, @intCast(i));

            if (sudoku.is_safe_move(coord, num)) {
                sudoku.set(coord, num);

                if (self.basic_solve(sudoku)) {
                    return true;
                }

                sudoku.set(coord, board.EmptySentinel);
            }
        }

        return false;
    }

    // No more unassigned spots.
    return true;
}
