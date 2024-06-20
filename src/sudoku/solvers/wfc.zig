const std = @import("std");
const Board = @import("../board.zig");
const Coordinate = @import("../Coordinate.zig");
const QBoard = @import("../quantum_board.zig");

const Self = @This();

const BoardType = QBoard.QuantumBoard(3, 3, .HEAP);

const SudokuError = error{
    Invalid,
};

const WeightType = struct {
    weight: u64,
    coord: Coordinate,
};

pub fn init() Self {
    return Self{};
}

pub fn deinit(self: Self) void {
    _ = self;
}

fn solve_init(sudoku: anytype, allocator: std.mem.Allocator) BoardType {
    var board = BoardType.init(allocator);

    // clear board ( boolean array is filled with all possible values)
    for (0..board.size) |j| { // col
        for (0..board.size) |i| { // row
            const c = Coordinate{ .i = i, .j = j };
            board.set(c, 0b111111111);
        }
    }

    for (0..sudoku.size) |j| { // col
        for (0..sudoku.size) |i| { // row
            const c = Coordinate{ .i = i, .j = j };

            const v = sudoku.get(c);

            if (v == Board.EmptySentinel) continue;

            _ = set_cell(&board, c, v);
        }
    }

    return board;
}

fn set_cell(board: *const BoardType, coord: Coordinate, value: u7) bool {
    // set cell, if down to 1 possibility on any updated,000

    const mask: u64 = @as(u64, 1) << @truncate(value - 1);

    // set cell
    board.set(coord, mask);

    // update row (i)
    const row = coord.i;

    for (0..board.size) |j| {
        if (j == coord.j) continue;

        const c: Coordinate = .{ .i = row, .j = j };
        const old: u64 = board.get(c);
        const val: u64 = old & (~mask);

        board.set(c, val);

        if (@popCount(old) > 1 and @popCount(val) == 1) {
            if (set_cell(board, c, @ctz(val) + 1) == false) return false;
        } else if (@popCount(val) == 0) return false;
    }

    // update column (j)
    const col = coord.j;

    for (0..board.size) |i| {
        if (i == coord.i) continue;

        const c: Coordinate = .{ .i = i, .j = col };
        const old: u64 = board.get(c);
        const val: u64 = old & (~mask);

        board.set(c, val);

        if (@popCount(old) > 1 and @popCount(val) == 1) {
            if (set_cell(board, c, @ctz(val) + 1) == false) return false;
        } else if (@popCount(val) == 0) return false;
    }

    // update square
    const sqRow = (coord.i / board.n) * board.k;
    const sqCol = (coord.j / board.n) * board.k;

    for (sqRow..sqRow + board.k) |i| {
        for (sqCol..sqCol + board.k) |j| {
            if (i == coord.i and j == coord.j) continue;

            const c: Coordinate = .{ .i = i, .j = j };
            const old: u64 = board.get(c);
            const val: u64 = old & (~mask);

            board.set(c, val);

            if (@popCount(old) > 1 and @popCount(val) == 1) {
                if (set_cell(board, c, @ctz(val) + 1) == false) return false;
            } else if (@popCount(val) == 0) return false;
        }
    }

    return true;
}

fn solve_internal(board: *const BoardType, allocator: std.mem.Allocator) !bool {
    var optimal: WeightType = .{ .weight = 9999, .coord = .{ .i = 99, .j = 99 } };

    // find uncertain cells
    for (0..board.size) |i| {
        for (0..board.size) |j| {
            const c: Coordinate = .{ .i = i, .j = j };
            if (@popCount(board.get(c)) == 1) continue;
            // rank uncertain cells based on entropy
            const weight = rank_cell(board.*, c) catch return false;

            if (weight > optimal.weight) continue;

            optimal.weight = weight;
            optimal.coord = c;
        }
    }

    // return if we are done
    if (optimal.weight == 9999) return true;

    // start with lowest entropy (last in stack)
    var newBoard = BoardType.init(allocator);
    defer newBoard.deinit();

    const val = board.get(optimal.coord);

    for (0..board.size) |i| {
        if ((val >> @truncate(i)) & 1 == 0) continue;

        newBoard.copy(board.*);
        if (!set_cell(&newBoard, optimal.coord, @truncate(i + 1))) {
            continue;
        }

        if (try solve_internal(&newBoard, allocator)) {
            board.copy(newBoard);
            return true;
        }
    }

    return false;
}

// wave function collapse method
// cell with each possible number in it
pub fn solve(self: Self, sudoku: anytype, allocator: std.mem.Allocator) !bool {
    _ = self;

    // check input
    if (sudoku.n != sudoku.k) {
        return false; // non deterministic (not yet implemented)
    }

    // create quantum board
    var qb = solve_init(sudoku, allocator);
    defer qb.deinit();
    _ = try solve_internal(&qb, allocator);

    for (0..sudoku.size) |i| {
        for (0..sudoku.size) |j| {
            const c = Coordinate{ .i = i, .j = j };
            const v = qb.get(c);
            if (@popCount(v) > 1) {
                sudoku.set(c, Board.EmptySentinel);
            } else {
                sudoku.set(c, @truncate(@ctz(v) + 1));
            }
        }
    }
    return true;
}

fn rank_cell(board: BoardType, coord: Coordinate) !u64 {
    var pop = @popCount(board.get(coord));
    if (pop == 0) return SudokuError.Invalid;
    var weight: u64 = pop - 1;

    const row = coord.i;
    for (0..board.size) |j| {
        if (j == coord.j) continue;

        const c: Coordinate = .{ .i = row, .j = j };
        pop = @popCount(board.get(c));
        if (pop == 0) return SudokuError.Invalid;
        weight += pop - 1;
    }

    const col = coord.j;
    for (0..board.size) |i| {
        if (i == coord.i) continue;

        const c: Coordinate = .{ .i = i, .j = col };
        pop = @popCount(board.get(c));
        if (pop == 0) return SudokuError.Invalid;
        weight += pop - 1;
    }

    const sqRow = (coord.i / board.n) * board.k;
    const sqCol = (coord.j / board.n) * board.k;

    for (sqRow..sqRow + board.k) |i| {
        for (sqCol..sqCol + board.k) |j| {
            if (i == coord.i and j == coord.j) continue;

            const c: Coordinate = .{ .i = i, .j = j };
            pop = @popCount(board.get(c));
            if (pop == 0) return SudokuError.Invalid;
            weight += pop - 1;
        }
    }

    return weight;
}

fn sortWeightVals(vals: []WeightType) void {
    for (0..vals.len - 1) |i| {
        for (i..vals.len) |j| {
            if (vals[j].weight > vals[i].weight) {
                const temp: WeightType = vals[i];
                vals[i] = vals[j];
                vals[j] = temp;
            }
        }
    }
}
