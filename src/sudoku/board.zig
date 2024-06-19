const std = @import("std");
const pow = std.math.pow;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Coordinate = @import("Coordinate.zig");

pub const SudokuSize = enum { _4x4, _9x9, _16x16, _25x25 };

/// Compact and readable sudoku type.
pub fn Sudoku(comptime size: SudokuSize) type {
    return switch (size) {
        ._4x4 => Board(2, 2, .HEAP),
        ._9x9 => Board(3, 3, .HEAP),
        ._16x16 => Board(4, 4, .HEAP),
        ._25x25 => Board(5, 5, .HEAP),
    };
}

/// Corresponds to the default 9x9 sudoku.
pub const DefaultBoard = Sudoku(._9x9);
pub const Sudoku4x4 = Sudoku(._4x4);
pub const Sudoku9x9 = Sudoku(._9x9);
pub const Sudoku16x16 = Sudoku(._16x16);
pub const Sudoku25x25 = Sudoku(._25x25);

pub const BoardContraint = enum { ROW, COLUMN, GRID };
pub const StorageMemory = enum { STACK, HEAP };
pub const EmptySentinel = 0;

/// TODO rewrite type.
fn BoardCoordIterator(comptime C: BoardContraint) type {
    switch (C) {
        .ROW => {
            return struct {
                start: Coordinate,
                end: Coordinate,
                done: bool,

                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.size);
                    const coord = Coordinate.new_row_coord(constraint_index, 0);
                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: Coordinate) @This() {
                    return @This(){
                        .start = coord.get_first_row_coord(),
                        .end = coord.get_last_row_coord(sudoku.size),
                        .done = false,
                    };
                }

                pub fn next(self: *@This()) ?Coordinate {
                    if (self.done) {
                        return null;
                    }

                    const current = self.start;

                    if (current.equals(self.end)) {
                        self.done = true;
                        return self.end;
                    }

                    self.start.j += 1;

                    return current;
                }
            };
        },
        .COLUMN => {
            return struct {
                start: Coordinate,
                end: Coordinate,
                done: bool,

                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    // The size of the sudoku is the same as the row column count.
                    assert(constraint_index < sudoku.size);
                    const coord = Coordinate.new_col_coord(constraint_index, 0);
                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: Coordinate) @This() {
                    return @This(){
                        .start = coord.get_first_col_coord(),
                        .end = coord.get_last_col_coord(sudoku.size),
                        .done = false,
                    };
                }

                pub fn next(self: *@This()) ?Coordinate {
                    if (self.done) {
                        return null;
                    }

                    const current = self.start;

                    if (current.equals(self.end)) {
                        self.done = true;
                        return self.end;
                    }

                    self.start.i += 1;

                    return current;
                }
            };
        },
        .GRID => {
            return struct {
                start: Coordinate,
                end: Coordinate,
                n: usize,
                done: bool,

                /// TODO: We started with init() only, so initIndex and init contain
                /// duplicate / negated logic. We should refactor this.
                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.k * sudoku.k);

                    const coord = Coordinate.new_grid_coord(constraint_index, sudoku.k, sudoku.n, 0);

                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: Coordinate) @This() {
                    return @This(){
                        .start = coord.get_first_grid_coord(sudoku.k, sudoku.n),
                        .end = coord.get_last_grid_coord(sudoku.k, sudoku.n),
                        .n = sudoku.n,
                        .done = false,
                    };
                }

                pub fn next(self: *@This()) ?Coordinate {
                    if (self.done) {
                        return null;
                    }

                    const current = self.start;

                    if (current.equals(self.end)) {
                        self.done = true;
                        return self.end;
                    }

                    if (self.start.j == self.end.j) {
                        self.start.j = self.end.j - (self.n - 1);
                        self.start.i += 1;
                    } else {
                        self.start.j += 1;
                    }

                    return current;
                }
            };
        },
    }
}

/// Infer size of type to fit valid sudoku. From description.
/// In practice unless you allow a row to be shorter than N^2
/// K is strictly equal to N.
pub fn StorageType(comptime K: u16, comptime N: u16) type {
    // We use numbers from 1 to N^2
    const size = K * N;
    const numbers = N * N;
    const area = pow(usize, N, 2);

    // assert sudoku is of valid size
    // n ** 2 has be equal to the length of the diagonal.
    if (size < area) {
        @compileError(std.fmt.comptimePrint("Row and column have {d} inputs but the {d}x{d} grid has {d}\n", .{ size, N, N, area }));
    }

    if (numbers != size) {
        @compileError(std.fmt.comptimePrint("N * N ({d}) must be equal to K * N ({d})\n", .{ numbers, size }));
    }

    // Find the smallest number of bits that can fit all numbers.
    const value_size = @as(usize, @intFromFloat(std.math.floor(std.math.log2(@as(f64, @floatFromInt(numbers)))))) + 1;

    if (value_size > @bitSizeOf(usize)) {
        @compileError("Value size is too large for storage type");
    }

    return struct {
        pub const ValueType = std.meta.Int(.unsigned, value_size);
        pub const BitFieldType = std.meta.Int(.unsigned, numbers);
    };
}

/// Internal representation of Sudoku.
/// A storage type which contains size bits.
/// We store a single value as a bitfield where its index is its value.
/// We can use this to optimize for solving, as we can use bitwise operations to check for valid moves.
///
/// The matrix storage layout is a simple 2D array. (size * size)
///
/// The bitfield storage layout stores each constraint in a single field, one for every row, every column and every grid. (2*size + 2*k)
/// They are stored in a flat array with row, column and grid constraints in that order.
pub fn Board(comptime _K: u16, comptime _N: u16, comptime memory: StorageMemory) type {
    const _Storage = StorageType(_K, _N);
    const _size = @bitSizeOf(_Storage.BitFieldType);

    const bitfield_storage_size = _size * 2 + _K * _K;
    const matrix_storage_size = _size * _size;

    const Constraint = struct {
        const Self = @This();

        pub inline fn possible_values(board: anytype, coord: Coordinate) _Storage.BitFieldType {
            return ~(board.constraints[coord.i] | board.constraints[coord.j + _size] | board.constraints[coord.get_grid_index(_K, _N) + 2 * _size]);
        }

        pub inline fn contains(board: anytype, coord: Coordinate, value: _Storage.ValueType) bool {
            assert(value > 0);

            const amt: _Storage.ValueType = value - 1;
            const mask: _Storage.BitFieldType = std.math.shl(_Storage.BitFieldType, 1, amt);

            return (board.constraints[coord.i] & mask != 0) or (board.constraints[coord.j + _size] & mask != 0) or (board.constraints[coord.get_grid_index(_K, _N) + 2 * _size] & mask != 0);
        }

        pub inline fn bit_or(board: anytype, coord: Coordinate, mask: _Storage.BitFieldType) void {
            board.constraints[coord.i] |= mask;
            board.constraints[coord.j + _size] |= mask;
            board.constraints[coord.get_grid_index(_K, _N) + 2 * _size] |= mask;
        }

        pub inline fn bit_and(board: anytype, coord: Coordinate, mask: _Storage.BitFieldType) void {
            board.constraints[coord.i] &= mask;
            board.constraints[coord.j + _size] &= mask;
            board.constraints[coord.get_grid_index(_K, _N) + 2 * _size] &= mask;
        }
    };

    return struct {
        const Self = @This();

        pub const K = _K;
        pub const N = _N;
        pub const size = _size;

        pub const Storage = _Storage;

        // Store the (x, y) values of the board.
        // To know what field is set at (x, y).
        pub const MatrixBoardType = switch (memory) {
            .STACK => [matrix_storage_size]Storage.ValueType,
            .HEAP => []Storage.ValueType,
        };

        // Optimize lookup for constraints.
        // by storing bitfields for each row, column and grid.
        pub const BitfieldConstraintsType = switch (memory) {
            .STACK => [bitfield_storage_size]Storage.BitFieldType,
            .HEAP => []Storage.BitFieldType,
        };

        allocator: ?std.mem.Allocator,
        board: MatrixBoardType,
        constraints: BitfieldConstraintsType,
        size: usize,
        k: usize,
        n: usize,

        pub fn init(allocator: ?std.mem.Allocator) Self {
            const board = switch (memory) {
                .STACK => [_]Storage.ValueType{EmptySentinel} ** matrix_storage_size,
                .HEAP => allocator.?.alloc(Storage.ValueType, matrix_storage_size) catch |err| {
                    @panic(@errorName(err));
                },
            };

            if (memory == .HEAP) {
                @memset(board, EmptySentinel);
            }

            const constraints = switch (memory) {
                .STACK => [_]Storage.BitFieldType{0} ** bitfield_storage_size,
                .HEAP => allocator.?.alloc(Storage.BitFieldType, bitfield_storage_size) catch |err| {
                    @panic(@errorName(err));
                },
            };

            if (memory == .HEAP) {
                @memset(constraints, 0);
            }

            return Self{
                .allocator = allocator,
                .board = board,
                .constraints = constraints,
                .size = size,
                .k = K,
                .n = N,
            };
        }

        pub fn deinit(self: *Self) void {
            if (memory == .HEAP) {
                if (self.allocator != null) {
                    self.allocator.?.free(self.board);
                    self.allocator.?.free(self.constraints);
                } else {
                    @panic("No allocator provided");
                }
            }
        }

        fn clear_board(self: *Self) void {
            switch (memory) {
                .STACK => {
                    for (0..matrix_storage_size) |i| {
                        self.board[i] = EmptySentinel;
                    }
                },
                .HEAP => {
                    @memset(self.board, EmptySentinel);
                },
            }
        }

        fn clear_constraints(self: *Self) void {
            switch (memory) {
                .STACK => {
                    for (0..bitfield_storage_size) |i| {
                        self.constraints[i] = 0;
                    }
                },
                .HEAP => {
                    @memset(self.constraints, 0);
                },
            }
        }

        pub fn clear(self: *Self) void {
            self.clear_board();
            self.clear_constraints();
        }

        pub fn copy(self: Self, allocator: std.mem.Allocator) Board(K, N, .HEAP) {
            const new_board = Board(K, N, .HEAP).init(allocator);

            std.mem.copyForwards(Storage.ValueType, new_board.board, self.board);
            std.mem.copyForwards(Storage.BitFieldType, new_board.constraints, self.constraints);

            return new_board;
        }

        /// Get the value of the field at i, j.
        pub inline fn get(self: *const Self, coordinate: Coordinate) Storage.ValueType {
            assert(self.size == size);
            assert(coordinate.i < size and coordinate.j < size);

            return self.board[coordinate.i * size + coordinate.j];
        }

        /// Rebuild internal state from board data.
        pub fn rebuild(self: *Self) void {
            self.clear_constraints();

            for (0..size) |i| {
                for (0..size) |j| {
                    const coord = Coordinate{ .i = i, .j = j };
                    const value = self.get(coord);

                    if (value != EmptySentinel) {
                        assert(!Constraint.contains(self, coord, value));

                        const amt: Storage.ValueType = value - 1;
                        const mask: Storage.BitFieldType = std.math.shl(Storage.BitFieldType, 1, amt);
                        Constraint.bit_or(self, coord, mask);
                    }
                }
            }
        }

        /// Set the value of the field at i, j to value.
        /// Ensures constraints are updated.
        /// When setting board directly use rebuild function.
        pub inline fn set(self: *Self, coord: Coordinate, value: Storage.ValueType) void {
            assert(self.size == size);
            assert(value <= self.size and coord.i < size and coord.j < size);

            const current_value = self.get(coord);

            if (current_value == value) {
                return;
            }

            // Cannot reuse the same value in the same row, column or grid.
            // TODO: maybe return error type.
            if (value != EmptySentinel and Constraint.contains(self, coord, value)) {
                @panic("Invalid move");
            }

            // Clear out constraints.
            if (current_value != EmptySentinel) {
                const amt: Storage.ValueType = current_value - 1;
                const mask: Storage.BitFieldType = ~std.math.shl(Storage.BitFieldType, 1, amt);
                Constraint.bit_and(self, coord, mask);
            }

            // Set the value in the matrix.
            self.board[coord.i * size + coord.j] = value;

            // We can't set empty values in constraints.
            if (value == EmptySentinel) {
                return;
            }

            // We have to set the value in all constraints.
            // We can reuse the same mask for all constraints.
            const amt: Storage.ValueType = value - 1;
            const mask: Storage.BitFieldType = std.math.shl(Storage.BitFieldType, 1, amt);
            Constraint.bit_or(self, coord, mask);
        }

        /// Access a constraint based on its index
        /// So row N, col N or grid N.
        pub fn index_iterator(self: *Self, comptime C: BoardContraint, constraint_index: usize) BoardCoordIterator(C) {
            return BoardCoordIterator(C).initIndex(self, constraint_index);
        }

        /// Access the constraint based on any value from inside of it.
        /// Ei. coordinate X belongs to contraint N in row / col / grid.
        pub fn coord_iterator(self: *Self, comptime C: BoardContraint, coord: Coordinate) BoardCoordIterator(C) {
            return BoardCoordIterator(C).init(self, coord);
        }

        /// Set entire row based on its index and a list of values.
        pub fn set_row(self: *Self, index: usize, values: [size]Storage.ValueType) void {
            var it = self.index_iterator(.ROW, index);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        /// Set entire col based on its index and a list of values.
        pub fn set_col(self: *Self, index: usize, values: [size]Storage.ValueType) void {
            var it = self.index_iterator(.COLUMN, index);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        /// Set entire grid based on its index and a list of values.
        pub fn set_grid(self: *Self, index: usize, values: [N * N]Storage.ValueType) void {
            var it = self.index_iterator(.GRID, index);

            for (0..(N * N)) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        fn iterator_contains(self: *Self, iterator: anytype, value: Storage.ValueType) bool {
            while (iterator.next()) |current| {
                if (self.get(current) == value) {
                    return true;
                }
            }

            return false;
        }

        pub inline fn is_safe_move(self: *Self, coord: Coordinate, value: Storage.ValueType) bool {
            const current_value = self.get(coord);

            // Cannot set a field that is already set.
            // Maybe this should return true if the value is the same.
            // Most likely not.
            if (current_value != EmptySentinel) {
                return false;
            }

            return !Constraint.contains(self, coord, value);
        }

        pub inline fn get_possibility_count(self: *Self, coord: Coordinate) usize {
            const bitfield = Constraint.possible_values(self, coord);

            var count: usize = 0;

            inline for (0..size) |i| {
                if (bitfield & std.math.shl(Storage.BitFieldType, 1, i) != 0) {
                    count += 1;
                }
            }

            return count;
        }

        /// Get a list of all possible values for a coordinate.
        /// This is used for backtracking.
        pub fn get_possibilities(self: *Self, coord: Coordinate, allocator: std.mem.Allocator) ![]Storage.ValueType {
            const possible_bitfield = Constraint.possible_values(self, coord);

            var possibilities = std.ArrayList(Storage.ValueType).init(allocator);

            inline for (0..size) |i| {
                if (possible_bitfield & std.math.shl(Storage.BitFieldType, 1, i) != 0) {
                    try possibilities.append(@intCast(i + 1));
                }
            }

            return possibilities.toOwnedSlice();
        }

        /// Random fill, not real puzzle generation.
        pub fn fill_random_valid(self: *Self, max_filled: usize, max_attemps: usize, rng: *std.Random) void {
            var succesful_fills: usize = 0;

            for (0..max_attemps) |_| {
                if (succesful_fills >= max_filled) {
                    break;
                }

                const coord = Coordinate.random(size, rng);

                const value = rng.intRangeLessThan(Storage.ValueType, 1, @intCast(size + 1));

                if (self.is_safe_move(coord, value)) {
                    self.set(coord, value);
                    succesful_fills += 1;
                }
            }
        }

        /// Debug function to print board.
        /// TODO: Actually make this work for abitrary sizes.
        pub fn display(self: *const Self, writer: anytype) !void {
            // Format in correct grid squares.
            // Border with | and -.
            var int_buf: [2]u8 = [_]u8{0} ** 2;
            const min_text_width = std.math.log10(size + 1) + 1;
            const line_width = K * N * (min_text_width) + 7;

            for (0..size) |i| {
                if (i % self.n == 0) {
                    for (0..line_width) |_| {
                        _ = try writer.write("-");
                    }
                    _ = try writer.write("\n");
                }

                for (0..size) |j| {
                    const value = self.get(.{ .i = i, .j = j });

                    if (j == 0) {
                        _ = try writer.write("|");
                    }

                    const text_width = if (value == EmptySentinel) 1 else std.math.log10(value) + 1;
                    const spaces = if (min_text_width - text_width <= 0) 1 else min_text_width - text_width;

                    for (0..spaces) |_| {
                        _ = try writer.write(" ");
                    }

                    if (value == EmptySentinel) {
                        _ = try writer.write(".");
                    } else {
                        _ = try writer.write(try std.fmt.bufPrint(&int_buf, "{d}", .{value}));
                    }

                    if ((j + 1) % self.n == 0) {
                        _ = try writer.write(" |");
                    }
                }

                _ = try writer.write("\n");

                if (i == size - 1) {
                    for (0..line_width) |_| {
                        _ = try writer.write("-");
                    }
                    _ = try writer.write("\n");
                }
            }

            _ = try writer.write("\n");
        }
    };
}

test "Validate certain sudoku board sizes" {
    _ = Board(2, 2, .STACK);
    _ = Board(3, 3, .STACK);
}

test "Test 4x4 Sudoku" {
    // Also test memory leaks.
    const S = Board(2, 2, .HEAP);

    const allocator = std.testing.allocator;
    var s = S.init(allocator);
    defer s.deinit();

    s.set(.{ .i = 0, .j = 0 }, 1);
    s.set(.{ .i = 0, .j = 1 }, 2);
    s.set(.{ .i = 1, .j = 0 }, 3);
    s.set(.{ .i = 1, .j = 1 }, 0);

    try expect(s.get(.{ .i = 0, .j = 0 }) == 1);
    try expect(s.get(.{ .i = 0, .j = 1 }) == 2);
    try expect(s.get(.{ .i = 1, .j = 0 }) == 3);
    try expect(s.get(.{ .i = 1, .j = 1 }) == 0);

    var it_row = s.index_iterator(.ROW, 0);

    try expect(it_row.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 2 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 3 }));
    try expect(it_row.next() == null);

    var it_col = s.index_iterator(.COLUMN, 0);

    try expect(it_col.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 2, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 3, .j = 0 }));
    try expect(it_col.next() == null);

    var it_grid = s.index_iterator(.GRID, 0);

    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 1 }));
    try expect(it_grid.next() == null);
}

test "Test 9x9 Sudoku" {
    const S = Board(3, 3, .STACK);

    var s = S.init(null);

    s.set_row(0, .{ 1, 2, 3, 4, 5, 6, 7, 8, 9 });

    try expect(s.get(.{ .i = 0, .j = 0 }) == 1);
    try expect(s.get(.{ .i = 0, .j = 1 }) == 2);
    try expect(s.get(.{ .i = 0, .j = 2 }) == 3);
    try expect(s.get(.{ .i = 0, .j = 3 }) == 4);
    try expect(s.get(.{ .i = 0, .j = 4 }) == 5);
    try expect(s.get(.{ .i = 0, .j = 5 }) == 6);
    try expect(s.get(.{ .i = 0, .j = 6 }) == 7);
    try expect(s.get(.{ .i = 0, .j = 7 }) == 8);
    try expect(s.get(.{ .i = 0, .j = 8 }) == 9);

    var it_row = s.index_iterator(.ROW, 0);

    try expect(it_row.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 2 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 3 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 4 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 5 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 6 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 7 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 8 }));
    try expect(it_row.next() == null);

    var it_col = s.index_iterator(.COLUMN, 0);

    try expect(it_col.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 2, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 3, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 4, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 5, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 6, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 7, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 8, .j = 0 }));
    try expect(it_col.next() == null);

    var it_grid = s.index_iterator(.GRID, 0);

    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 2 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 1 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 2 }));
    try expect(it_grid.next().?.equals(.{ .i = 2, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 2, .j = 1 }));
    try expect(it_grid.next().?.equals(.{ .i = 2, .j = 2 }));
    try expect(it_grid.next() == null);
}

test "Very large using matrix backend, does it compile?" {
    const S = Board(32, 32, .HEAP);

    var s = S.init(std.testing.allocator);
    defer s.deinit();

    s.set(.{ .i = 999, .j = 999 }, 1000);

    try expect(s.get(.{ .i = 999, .j = 999 }) == 1000);
}

test "Test internal bitfield implementation" {
    var b = DefaultBoard.init(std.testing.allocator);
    defer b.deinit();

    // This sets the first bit in 3 constraints.
    b.set(.{ .i = 0, .j = 0 }, 1);

    // This removes the first bit in 3 constraints.
    b.set(.{ .i = 0, .j = 0 }, 0);

    // This sets the first bit in 3 constraints.
    b.set(.{ .i = 0, .j = 0 }, 1);
}

test "Test Copy" {
    var b = DefaultBoard.init(std.testing.allocator);
    defer b.deinit();

    b.set(.{ .i = 0, .j = 0 }, 1);
    b.set(.{ .i = 0, .j = 1 }, 2);
    b.set(.{ .i = 1, .j = 0 }, 3);
    b.set(.{ .i = 1, .j = 1 }, 0);

    var c = b.copy(std.testing.allocator);
    defer c.deinit();

    try expect(c.get(.{ .i = 0, .j = 0 }) == 1);
    try expect(c.get(.{ .i = 0, .j = 1 }) == 2);
    try expect(c.get(.{ .i = 1, .j = 0 }) == 3);
    try expect(c.get(.{ .i = 1, .j = 1 }) == 0);

    // CHange c and make sure b is not changed.
    c.set(.{ .i = 0, .j = 0 }, 0);
    try expect(b.get(.{ .i = 0, .j = 0 }) == 1);
}
