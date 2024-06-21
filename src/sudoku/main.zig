const std = @import("std");

const board = @import("board.zig");
const parse = @import("parse.zig");
const solve = @import("solve.zig");
const puzzle_gen = @import("puzzle_gen.zig");

pub fn test_worst_case(solver: solve.Solvers, allocator: std.mem.Allocator) !void {
    var b = board.DefaultBoard.init(allocator);
    defer b.deinit();

    // No solutions
    b.set_row(0, .{ 0, 0, 5, 0, 0, 0, 0, 9, 0 });
    b.set_row(1, .{ 0, 8, 0, 0, 0, 0, 0, 0, 0 });
    b.set_row(2, .{ 0, 0, 0, 0, 0, 0, 0, 2, 0 });
    b.set_row(3, .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    b.set_row(4, .{ 0, 6, 0, 0, 0, 3, 0, 0, 8 });
    b.set_row(5, .{ 0, 0, 0, 0, 0, 0, 2, 0, 0 });
    b.set_row(6, .{ 0, 0, 0, 0, 4, 0, 0, 0, 0 });
    b.set_row(7, .{ 0, 0, 0, 5, 0, 0, 8, 0, 0 });
    b.set_row(8, .{ 1, 0, 3, 0, 0, 0, 0, 0, 0 });

    const writer = std.io.getStdOut().writer();

    _ = try b.display(writer);
    _ = try solve.solve(solver, &b, allocator);
    _ = try b.display(writer);
}

pub fn fuzz(comptime sudoku_size: board.SudokuSize, solver: solve.Solvers, allocator: std.mem.Allocator, gen_clues: usize) !void {
    const SudokuT = board.Sudoku(sudoku_size);
    const K = SudokuT.K;
    const N = SudokuT.N;

    var stencil = parse.Stencil(K, N).init(allocator);
    const writer = std.io.getStdErr().writer();
    var buffer_writer = std.io.bufferedWriter(writer);

    for (0..std.math.maxInt(u32)) |i| {
        std.debug.print("({d}) ", .{i});
        var b2 = puzzle_gen.generate_puzzle(K, N, solver, true, gen_clues, std.math.maxInt(usize), allocator) catch continue;
        const v = stencil.into(b2) catch continue;
        _ = try b2.display(&buffer_writer);
        _ = try buffer_writer.write(v);
        _ = try buffer_writer.write("\n");
        try buffer_writer.flush();
        allocator.free(v);
        b2.deinit();
    }
}

pub fn gen_100k_bench(comptime sudoku_size: board.SudokuSize, solver: solve.Solvers, allocator: std.mem.Allocator) void {
    const SudokuT = board.Sudoku(sudoku_size);
    const K = SudokuT.K;
    const N = SudokuT.N;

    const start_time = std.time.nanoTimestamp();

    for (0..100_000) |_| {
        var b2 = puzzle_gen.generate_puzzle(K, N, solver, false, 5, 20, allocator) catch continue;
        defer b2.deinit();
    }
    const total_time = std.time.nanoTimestamp() - start_time;

    std.debug.print("Total time: {d} ns & {d} ms\n", .{ total_time, @as(f64, @floatFromInt(total_time)) / 1_000_000.0 });
}

pub fn solve_stencil(comptime sudoku_size: board.SudokuSize, solver: solve.Solvers, allocator: std.mem.Allocator, stencil: []u8) !void {
    const SudokuT = board.Sudoku(sudoku_size);
    const K = SudokuT.K;
    const N = SudokuT.N;

    const writer = std.io.getStdOut().writer();

    var p = parse.Stencil(K, N).init(allocator);
    var b = p.from(stencil);
    defer b.deinit();

    try b.display(writer);

    _ = try solve.solve(solver, &b, allocator);

    try b.display(writer);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    const args = argv[1..];

    // Get and print them!
    if (args.len < 3) {
        std.debug.print("Usage: {s} <sudoku_size> <solver> <test> <input?>\n", .{argv[0]});
        std.debug.print("  sudoku_size: 4x4, 9x9, 16x16, 25x25\n", .{});
        std.debug.print("  solver: WFC, MRV\n", .{});
        std.debug.print("  tests: test_worst_case (Only 9x9), gen_100k_bench, fuzz <gen_clues>, solve_stencil <stencil str>\n", .{});
        return;
    }

    const size_arg = args[0];
    const solver_arg = args[1];
    const test_arg = args[2];

    var sudoku_size: board.SudokuSize = ._9x9;

    if (std.mem.eql(u8, size_arg, "4x4")) {
        sudoku_size = ._4x4;
    } else if (std.mem.eql(u8, size_arg, "9x9")) {
        sudoku_size = ._9x9;
    } else if (std.mem.eql(u8, size_arg, "16x16")) {
        sudoku_size = ._16x16;
    } else if (std.mem.eql(u8, size_arg, "25x25")) {
        sudoku_size = ._25x25;
    } else {
        std.debug.print("Invalid sudoku size: {s}\n", .{size_arg});
        return;
    }

    var solver: solve.Solvers = .MRV;

    if (std.mem.eql(u8, solver_arg, "WFC")) {
        solver = .WFC;
    } else if (std.mem.eql(u8, solver_arg, "MRV")) {
        solver = .MRV;
    } else {
        std.debug.print("Invalid solver: {s}\n", .{solver_arg});
        return;
    }

    if (std.mem.eql(u8, test_arg, "test_worst_case") and sudoku_size == ._9x9) {
        try test_worst_case(solver, allocator);
    } else if (std.mem.eql(u8, test_arg, "gen_100k_bench")) {
        switch (sudoku_size) {
            ._4x4 => gen_100k_bench(._4x4, solver, allocator),
            ._9x9 => gen_100k_bench(._9x9, solver, allocator),
            ._16x16 => gen_100k_bench(._16x16, solver, allocator),
            ._25x25 => gen_100k_bench(._25x25, solver, allocator),
        }
    } else if (std.mem.eql(u8, test_arg, "fuzz") and args.len >= 4) {
        const gen_clues = try std.fmt.parseInt(usize, args[3], 10);

        try switch (sudoku_size) {
            ._4x4 => fuzz(._4x4, solver, allocator, gen_clues),
            ._9x9 => fuzz(._9x9, solver, allocator, gen_clues),
            ._16x16 => fuzz(._16x16, solver, allocator, gen_clues),
            ._25x25 => fuzz(._25x25, solver, allocator, gen_clues),
        };
    } else if (std.mem.eql(u8, test_arg, "solve_stencil") and args.len >= 4) {
        const stencil = args[3];
        try switch (sudoku_size) {
            ._4x4 => solve_stencil(._4x4, solver, allocator, stencil),
            ._9x9 => solve_stencil(._9x9, solver, allocator, stencil),
            ._16x16 => solve_stencil(._16x16, solver, allocator, stencil),
            ._25x25 => solve_stencil(._25x25, solver, allocator, stencil),
        };
    } else {
        std.debug.print("Invalid test: {s}\n", .{test_arg});
        return;
    }
}
