const std = @import("std");
const Self = @This();
const board = @import("../board.zig");
const Coordinate = @import("../Coordinate.zig");

arena: std.heap.ArenaAllocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{ .arena = std.heap.ArenaAllocator.init(allocator) };
}

pub fn deinit(self: Self) void {
    self.arena.deinit();
}

// Find an unassigned coordinate with the minimum possible values (MRV/Minimum Remaining Values heuristic)
fn find_unassigned_coord(sudoku: anytype) ?Coordinate {
    var min_pos: ?Coordinate = null;
    var min_possibilities = sudoku.size + 1;

    for (0..sudoku.size) |i| {
        for (0..sudoku.size) |j| {
            const pos = Coordinate{ .i = i, .j = j };

            if (sudoku.get(pos) == board.EmptySentinel) {
                const possibilities = sudoku.get_possibility_count(pos);
                if (possibilities < min_possibilities) {
                    min_pos = pos;
                    min_possibilities = possibilities;
                }
            }
        }
    }

    return min_pos;
}

pub fn solve(self: *Self, sudoku: anytype) !bool {
    if (find_unassigned_coord(sudoku)) |coord| {
        const allocator = self.arena.allocator();

        const possibilities = try sudoku.get_possibilities(coord, allocator);
        defer allocator.free(possibilities);

        for (possibilities) |num| {
            if (sudoku.is_safe_move(coord, num)) {
                sudoku.set(coord, num);

                if (try self.solve(sudoku)) {
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
