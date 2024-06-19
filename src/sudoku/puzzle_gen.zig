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

pub fn generate_puzzle_safe(comptime K: u16, comptime N: u16, clues: usize, allocator: std.mem.Allocator) board.Board(K, N, .HEAP) {
    var attemps: usize = 10;

    while (attemps > 0) {
        return generate_puzzle(K, N, clues, allocator) catch {
            attemps -= 1;
            continue;
        };
    }

    @panic("Could not generate a puzzle in 10 attemps (Unlucky) Use WFC instead.");
}

/// Generate a solvable sudoku puzzle with a given number of clues.
/// TODO: Maybe change the calling convention to take a preallocated board, although this is cleaner.
pub fn generate_puzzle(comptime K: u16, comptime N: u16, clues: usize, allocator: std.mem.Allocator) !board.Board(K, N, .HEAP) {
    var has_solution = false;

    var b = board.Board(K, N, .HEAP).init(allocator);

    // Clean up the board if the generation fails
    defer if (!has_solution) b.deinit();

    // Generate initial board
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var rand = rng.random();

    b.fill_random_valid(clues, clues, &rand);

    std.debug.print("Solving generated initial conditions:\n", .{});
    const stderr_writer = std.io.getStdErr().writer();
    var buffer_writer = std.io.bufferedWriter(stderr_writer);

    _ = try b.display(&buffer_writer);
    try buffer_writer.flush();

    const start_time = std.time.milliTimestamp();

    has_solution = try solve.solve(.MRV, &b, allocator);

    const total_time = std.time.milliTimestamp() - start_time;

    std.debug.print("Solved in {d} milliseconds\n", .{total_time});

    // Not all valid moves leads to a solvable board.
    if (!has_solution) {
        return GenerationError.PartialHasNoSolution;
    }

    // Remove clues until the clues count is reached
    while (count_clues(b) > clues) {
        const c = Coordinate.random(K * K, &rand);

        if (b.get(c) == board.EmptySentinel) {
            continue;
        }

        b.set(c, board.EmptySentinel);
    }

    // Return newly allocated board.
    return b;
}
