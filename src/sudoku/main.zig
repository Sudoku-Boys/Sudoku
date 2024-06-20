const std = @import("std");

const board = @import("board.zig");
const parse = @import("parse.zig");
const solve = @import("solve.zig");
const puzzle_gen = @import("puzzle_gen.zig");

pub fn main() !void {
    const optionalAllocator: std.mem.Allocator = std.heap.page_allocator;

    //const board_stencil = ".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....";
    //var parser = parse.Stencil(3, 3).init(optionalAllocator);
    //
    //// Allocates b.
    //var b = parser.from(board_stencil);
    //defer b.deinit();
    //

    var b = board.DefaultBoard.init(optionalAllocator);

    b.set_row(0, .{0, 0, 5, 0, 0, 0, 0, 9, 0});
    b.set_row(1, .{0, 8, 0, 0, 0, 0, 0, 0, 0});
    b.set_row(2, .{0, 0, 0, 0, 0, 0, 0, 2, 0});
    b.set_row(3, .{0, 0, 0, 0, 0, 0, 0, 0, 0});
    b.set_row(4, .{0, 6, 0, 0, 0, 3, 0, 0, 8});
    b.set_row(5, .{0, 0, 0, 0, 0, 0, 2, 0, 0});
    b.set_row(6, .{0, 0, 0, 0, 4, 0, 0, 0, 0});
    b.set_row(7, .{0, 0, 0, 5, 0, 0, 8, 0, 0});
    b.set_row(8, .{1, 0, 3, 0, 0, 0, 0, 0, 0});

    b.clear();

    b.set_row(0, .{0, 0, 0, 0, 0, 0, 7, 8, 0});
    b.set_row(1, .{4, 0, 0, 0, 0, 0, 0, 0, 9});
    b.set_row(2, .{0, 0, 0, 0, 0, 0, 0, 0, 0});
    b.set_row(3, .{0, 0, 0, 0, 0, 0, 0, 0, 0});
    b.set_row(4, .{0, 0, 0, 9, 0, 0, 0, 0, 0});
    b.set_row(5, .{0, 5, 8, 0, 0, 0, 3, 6, 0});
    b.set_row(6, .{6, 0, 9, 0, 0, 0, 0, 0, 0});
    b.set_row(7, .{0, 0, 0, 8, 7, 0, 0, 0, 0});
    b.set_row(8, .{0, 0, 4, 0, 0, 0, 0, 0, 0});

    const writer = std.io.getStdOut().writer();

    _ = try b.display(writer);

    _ = try solve.solve(.WFC, &b, optionalAllocator);
    _ = try b.display(writer);

    //
    //std.debug.print("Solveable: {}\n", .{solveable});
    //
    //std.debug.print("Grid count {d}\n", .{b.k * b.k});
    //
    //std.debug.print("As stencil {s}\n", .{try parser.into(b)});
    //
    //const errors = try b.validate_all(optionalAllocator);
    //
    //std.debug.print("Row errors count: {d}\n", .{errors.get(.ROW).items.len});
    //std.debug.print("Column errors count: {d}\n", .{errors.get(.COLUMN).items.len});
    //std.debug.print("Grid errors count: {d}\n", .{errors.get(.GRID).items.len});

    std.process.exit(0);

    const K = 3;
    const N = 3;

    var stencil = parse.Stencil(K, N).init(optionalAllocator);
    var buffer_writer = std.io.bufferedWriter(writer);

    for (0..std.math.maxInt(u32)) |i| {
        std.debug.print("({d}) ", .{i});
        var b2 = puzzle_gen.generate_puzzle(K, N, 20, optionalAllocator) catch continue;
        const v = stencil.into(b2) catch continue;
        _ = try b2.display(&buffer_writer);
        _ = try buffer_writer.write(v);
        _ = try buffer_writer.write("\n");
        try buffer_writer.flush();
        optionalAllocator.free(v);
        b2.deinit();
    }
}
