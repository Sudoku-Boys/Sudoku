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

pub fn fuzz(solver: solve.Solvers, allocator: std.mem.Allocator, gen_clues: usize) !void {
    const K = 3;
    const N = 3;

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

pub fn gen_100k_bench(solver: solve.Solvers, allocator: std.mem.Allocator) void {
    const K = 3;
    const N = 3;

    const start_time = std.time.nanoTimestamp();

    for (0..100_000) |_| {
        var b2 = puzzle_gen.generate_puzzle(K, N, solver, false, 5, 20, allocator) catch continue;
        defer b2.deinit();
    }
    const total_time = std.time.nanoTimestamp() - start_time;

    std.debug.print("Total time: {d} ns & {d} ms\n", .{total_time, @as(f64, @floatFromInt(total_time)) / 1_000_000.0});
}

pub fn solve_stencil(solver: solve.Solvers, allocator: std.mem.Allocator, stencil: []u8) !void {
    const K = 3;
    const N = 3;

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
    if (args.len < 2) {
        std.debug.print("Usage: {s} <solver> <test> <input?>\n", .{argv[0]});
        std.debug.print("  solver: WFC, MRV\n", .{});
        std.debug.print("  tests: test_worst_case, gen_100k_bench, fuzz <gen_clues>, solve_stencil <stencil str>\n", .{});
        return;
    }

    var solver: solve.Solvers = .MRV;

    if (std.mem.eql(u8, args[0], "WFC")) {
        solver = .WFC;
    } else if (std.mem.eql(u8, args[0], "MRV")) {
        solver = .MRV;
    } else {
        std.debug.print("Invalid solver: {s}\n", .{args[0]});
        return;
    }

    if (std.mem.eql(u8, args[1], "test_worst_case")) {
        try test_worst_case(solver, allocator);
    } else if (std.mem.eql(u8, args[1], "gen_100k_bench")) {
        gen_100k_bench(solver, allocator);
    } else if (std.mem.eql(u8, args[1], "fuzz") and args.len >= 3) {
        const gen_clues = try std.fmt.parseInt(usize, args[2], 10);
        try fuzz(solver, allocator, gen_clues);
    } else if (std.mem.eql(u8, args[1], "solve_stencil") and args.len >= 3) {
        const stencil = args[2];
        try solve_stencil(solver, allocator, stencil);
    } else {
        std.debug.print("Invalid test: {s}\n", .{args[1]});
        return;
    }
}
