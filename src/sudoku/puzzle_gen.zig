const std = @import("std");
const board = @import("board.zig");
const solve = @import("solve.zig");
const Coordinate = @import("Coordinate.zig");

const GenerationError = error{
    PartialHasNoSolution,
};

// Used to remove clues from the board
fn count_clues(sudoku: anytype) usize {
    var count: usize = 0;

    for (0..sudoku.size) |i| {
        for (0..sudoku.size) |j| {
            const c = Coordinate{ .i = i, .j = j };

            if (sudoku.get(c) != board.EmptySentinel) {
                count += 1;
            }
        }
    }

    return count;
}

/// Generate a solvable sudoku puzzle with a given number of clues.
/// TODO: Maybe change the calling convention to take a preallocated board, although this is cleaner.
pub fn generate_puzzle(comptime K: u16, comptime N: u16, clues: usize, allocator: *std.mem.Allocator) !*board.Board(K, N, .MATRIX, .HEAP) {
    var has_solution = false;

    var b = board.Board(K, N, .MATRIX, .HEAP).init(allocator);

    // Clean up the board if the generation fails
    defer {
        if (!has_solution) {
            b.deinit();
        }
    }

    // Generate initial board
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var rand = rng.random();

    b.fill_random_valid(20, 20, &rand);

    has_solution = try solve.solve(.ADVANCED, &b, allocator);

    // Not all valid moves leads to a solvable board.
    if (!has_solution) {
        return GenerationError.PartialHasNoSolution;
    }

    // Remove clues until the clues count is reached
    while (count_clues(b) > clues) {
        const c = Coordinate.random(K * K, &rand);

        if (b.get(c) == 0) {
            continue;
        }

        b.set(c, 0);
    }

    // Return newly allocated board.
    return &b;
}
