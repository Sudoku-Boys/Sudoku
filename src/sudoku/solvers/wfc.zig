const std = @import("std");
const Board = @import("../board.zig");
const EmptySentinel = Board.EmptySentinel;
const Coordinate = @import("../Coordinate.zig");
const assert = std.debug.assert;

const SudokuError = error{ Invalid };

const WeightType = struct {
    weight: usize,
    coord: Coordinate
};

pub fn QuantumBoard(comptime SudokuT: type, comptime memory: Board.StorageMemory) type {
    return struct {
        const Self = @This();

        pub const size = SudokuT.size;
        pub const BitFieldType = SudokuT.Storage.BitFieldType;

        pub const BoardStorageType = switch (memory) {
            .STACK => [size * size]BitFieldType,
            .HEAP => []BitFieldType,
        };


        pub const DefaultValue: BitFieldType = (1 << SudokuT.N * SudokuT.K) - 1;

        allocator: ?std.mem.Allocator,
        board: BoardStorageType,
        size: usize,
        k: usize,
        n: usize,

        pub fn init(allocator: ?std.mem.Allocator) Self {
            const board = switch (memory) {
                .STACK => [_]BitFieldType{DefaultValue} ** (size * size),
                .HEAP => allocator.?.alloc(BitFieldType, size * size) catch |err| {
                    @panic(@errorName(err));
                },
            };

            if (memory == .HEAP) {
                @memset(board, DefaultValue);
            }

            return Self{
                .allocator = allocator,
                .board = board,
                .size = size,
                .k = SudokuT.K,
                .n = SudokuT.N,
            };
        }

        pub fn get(self: *const Self, coordinate: Coordinate) BitFieldType {
            assert(self.size == size);
            assert(coordinate.i < size and coordinate.j < size);

            const field = self.board[coordinate.i * size + coordinate.j];

            return field;
        }

        pub fn set(self: *const Self, coordinate: Coordinate, value: BitFieldType) void {
            assert(self.size == size);
            assert(coordinate.i < size and coordinate.j < size);

            const index = coordinate.i * size + coordinate.j;

            self.board[index] = value;
        }

        pub fn copy(self: *const Self, other: Self) void {
            std.mem.copyForwards(BitFieldType, self.board, other.board);
        }

        pub fn clear(self: *Self) void {
            switch (memory) {
                .STACK => {
                    for (0..size * size) |i| {
                        self.board[i] = DefaultValue;
                    }
                },
                .HEAP => {
                    @memset(self.board, DefaultValue);
                },
            }
        }

        pub fn deinit(self: *Self) void {
            if (self.allocator) |allocator| {
                allocator.free(self.board);
            }
        }
    };
}

pub fn WaveFunctionCollapse(comptime SudokuT: type) type {
    return struct {
        const Self = @This();
        pub const QBoard = QuantumBoard(SudokuT, .HEAP);

        pub fn init() Self {
            return Self{};
        }

        pub fn deinit(self: Self) void {
            _ = self;
        }

        fn board_init(sudoku: *SudokuT, allocator: std.mem.Allocator) QBoard {
            var board = QBoard.init(allocator);

            // clear board ( boolean array is filled with all possible values)
            for (0..QBoard.size) |j| { // col
                for (0..QBoard.size) |i| { // row
                    const c = Coordinate{ .i = i, .j = j };
                    board.set(c, ~@as(QBoard.BitFieldType, 0));
                }
            }

            for (0..SudokuT.size) |j| { // col
                for (0..SudokuT.size) |i| { // row
                    const c = Coordinate{ .i = i, .j = j };

                    const v = sudoku.get(c);

                    if (v == Board.EmptySentinel) continue;

                    _ = set_cell(&board, c, v);
                }
            }

            return board;
        }

        // wave function collapse method
        // cell with each possible number in it
        pub fn solve(self: Self, sudoku: *SudokuT, allocator: std.mem.Allocator) !bool {
            _ = self;

            // create quantum board
            var qb = board_init(sudoku, allocator);
            defer qb.deinit();

            _ = try solve_internal(&qb, allocator);

            for (0..SudokuT.size) |i| {
                for (0..SudokuT.size) |j| {
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

        fn set_cell(board: anytype, coord: Coordinate, value: u7) bool {
            // set cell, if down to 1 possibility on any updated,000
            const mask: QBoard.BitFieldType = @as(QBoard.BitFieldType, 1) << @truncate(value - 1);

            // set cell
            board.set(coord, mask);

            // update row (i)
            const row = coord.i;

            for (0..board.size) |j| {
                if (j == coord.j) continue;

                const c: Coordinate = .{ .i = row, .j = j };
                const old: QBoard.BitFieldType = board.get(c);
                const val: QBoard.BitFieldType = old & (~mask);

                board.set(c, val);

                if (@popCount(old) > 1 and @popCount(val) == 1) {
                    if (set_cell(board, c, @ctz(val) + 1) == false) return false;
                } else if (@popCount(val) == 0) return false;
            }

            // update column (j)
            const col = coord.j;

            for (0..QBoard.size) |i| {
                if (i == coord.i) continue;

                const c: Coordinate = .{ .i = i, .j = col };
                const old: QBoard.BitFieldType = board.get(c);
                const val: QBoard.BitFieldType = old & (~mask);

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
                    const old: QBoard.BitFieldType = board.get(c);
                    const val: QBoard.BitFieldType = old & (~mask);

                    board.set(c, val);

                    if (@popCount(old) > 1 and @popCount(val) == 1) {
                        if (set_cell(board, c, @ctz(val) + 1) == false) return false;
                    } else if (@popCount(val) == 0) return false;
                }
            }

            return true;
        }

        fn solve_internal(board: anytype, allocator: std.mem.Allocator) !bool {
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
            var newBoard = @TypeOf(board.*).init(allocator);
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

        fn rank_cell(board: anytype, coord: Coordinate) !QBoard.BitFieldType {
            var pop = @popCount(board.get(coord));
            if (pop == 0) return SudokuError.Invalid;
            var weight: QBoard.BitFieldType = pop - 1;

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
        };
}
