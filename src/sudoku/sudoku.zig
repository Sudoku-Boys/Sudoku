const std = @import("std");
const pow = std.math.pow;
const assert = std.debug.assert;
const expect = std.testing.expect;

pub const SudokuContraint = enum { ROW, COLUMN, GRID };
pub const SudokuStorage = enum { BITFIELD, MATRIX };
pub const SudokuMemory = enum { STACK, HEAP };
pub const SudokuEmptySentinel = 0;

pub const SudokuCoordinate = struct {
    i: usize,
    j: usize,

    pub fn equals(self: SudokuCoordinate, other: SudokuCoordinate) bool {
        return self.i == other.i and self.j == other.j;
    }
};

fn SudokuContraintIterator(comptime C: SudokuContraint) type {
    switch (C) {
        .ROW => {
            return struct {
                start: SudokuCoordinate,
                end: SudokuCoordinate,

                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.size);
                    const coord = .{ .i = constraint_index, .j = 0 };
                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: SudokuCoordinate) @This() {
                    return @This(){
                        .start = .{ .i = coord.i, .j = 0 },
                        .end = .{ .i = coord.i, .j = sudoku.size },
                    };
                }

                pub fn next(self: *@This()) ?SudokuCoordinate {
                    const current = self.start;

                    if (current.equals(self.end)) {
                        return null;
                    }

                    self.start.j += 1;

                    return current;
                }
            };
        },
        .COLUMN => {
            return struct {
                start: SudokuCoordinate,
                end: SudokuCoordinate,

                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    // The size of the sudoku is the same as the row column count.
                    assert(constraint_index < sudoku.size);
                    const coord = .{ .i = 0, .j = constraint_index };
                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: SudokuCoordinate) @This() {
                    return @This(){
                        .start = .{ .i = 0, .j = coord.j },
                        .end = .{ .i = sudoku.size, .j = coord.j },
                    };
                }

                pub fn next(self: *@This()) ?SudokuCoordinate {
                    const current = self.start;

                    if (current.equals(self.end)) {
                        return null;
                    }

                    self.start.i += 1;

                    return current;
                }
            };
        },
        .GRID => {
            return struct {
                start: SudokuCoordinate,
                end: SudokuCoordinate,
                n: usize,

                /// TODO: We started with init() only, so initIndex and init contain
                /// duplicate / negated logic. We should refactor this.
                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.k * sudoku.k);

                    const row = constraint_index / sudoku.k;
                    const col = constraint_index % sudoku.k;

                    const coord = .{ .i = row * sudoku.n, .j = col * sudoku.n };

                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: SudokuCoordinate) @This() {
                    return @This(){
                        .start = .{ .i = coord.i - (coord.i % sudoku.n), .j = coord.j - (coord.j % sudoku.n) },
                        .end = .{ .i = coord.i - (coord.i % sudoku.n) + sudoku.n, .j = coord.j - (coord.j % sudoku.n) + sudoku.n },
                        .n = sudoku.n,
                    };
                }

                pub fn next(self: *@This()) ?SudokuCoordinate {
                    const current = self.start;

                    if (current.equals(self.end)) {
                        return null;
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

// Infer size of type to fit valid sudoku.
// From description.
fn SudokuBitFieldType(comptime K: u16, comptime N: u16) type {
    const size = K * N;
    const area = pow(usize, N, 2);

    // assert sudoku is of valid size
    // n ** 2 has be equal to the length of the diagonal.
    if (size < area) {
        @compileError(std.fmt.comptimePrint("Row and column have {d} inputs but the {d}x{d} grid has {d}\n", .{ size, N, N, area }));
    }

    return std.meta.Int(.unsigned, size);
}

pub fn SudokuValueRangeType(comptime K: u16, comptime N: u16) type {
    return std.meta.Int(.unsigned, @bitSizeOf(usize) - @clz(@as(usize, @max(@bitSizeOf(SudokuBitFieldType(K, N)) - 1, 0))));
}

fn SudokuValidationError(comptime T: type) type {
    return struct {
        coordinate: SudokuCoordinate,
        value: T,
    };
}

fn IndexIteratorFn(comptime C: SudokuContraint) type {
    return fn (*anyopaque, C, usize) SudokuContraintIterator(C);
}

fn CoordIteratorFn(comptime C: SudokuContraint) type {
    return fn (*anyopaque, C, SudokuCoordinate) SudokuContraintIterator(C);
}

pub const Sudoku = struct {
    const Self = @This();

    board: *anyopaque,
    board_get: *const fn (*anyopaque, SudokuCoordinate) usize,
    board_set: *const fn (*anyopaque, SudokuCoordinate, usize) void,
    board_clear: *const fn (*anyopaque) void,
    //board_index_iterator: *const fn (*anyopaque, comptime C: SudokuContraint, usize) SudokuContraintIterator,
    //board_coord_iterator: *const fn (*anyopaque, comptime C: SudokuContraint, SudokuCoordinate) SudokuContraintIterator,
    board_set_row: *const fn (*anyopaque, usize, []usize) void,
    board_set_col: *const fn (*anyopaque, usize, []usize) void,
    board_set_grid: *const fn (*anyopaque, usize, []usize) void,
    board_is_valid_then_set: *const fn (*anyopaque, SudokuCoordinate, usize) bool,
    // The rest of the functions are not so important rn.

    pub fn init(board: anytype) Self {
        const T = @TypeOf(board.*);

        return Self{
            .board = @ptrCast(board),
            .board_get = @ptrCast(&T.get),
            .board_set = @ptrCast(&T.set),
            .board_clear = @ptrCast(&T.clear),
            //.board_index_iterator = @ptrCast(&T.index_iterator),
            //.board_coord_iterator = @ptrCast(&T.coord_iterator),
            .board_set_row = @ptrCast(&T.set_row),
            .board_set_col = @ptrCast(&T.set_col),
            .board_set_grid = @ptrCast(&T.set_grid),
            .board_is_valid_then_set = @ptrCast(&T.is_valid_then_set),
        };
    }

    pub fn get(self: *const Self, coord: SudokuCoordinate) usize {
        return self.board_get(self.board, coord);
    }

    pub fn set(self: *const Self, coord: SudokuCoordinate, value: usize) void {
        self.board_set(self.board, coord, value);
    }

    pub fn clear(self: *const Self) void {
        self.board_clear(self.board);
    }

    pub fn set_row(self: *const Self, index: usize, values: []usize) void {
        self.board_set_row(self.board, index, values);
    }

    pub fn set_col(self: *const Self, index: usize, values: []usize) void {
        self.board_set_col(self.board, index, values);
    }

    pub fn set_grid(self: *const Self, index: usize, values: []usize) void {
        self.board_set_grid(self.board, index, values);
    }

    pub fn is_valid_then_set(self: *const Self, coord: SudokuCoordinate, value: usize) bool {
        return self.board_is_valid_then_set(self.board, coord, value);
    }
};

test "Type errasure" {
    const Sudoku3x3 = Board(3, 3, .MATRIX, .STACK);
    var s = Sudoku3x3.init(null);
    const c = SudokuCoordinate{ .i = 0, .j = 0 };

    const a = Sudoku.init(&s);

    a.set(c, 9);

    try expect(s.get(c) == 9);
    try expect(a.get(c) == 9);
}

// Internal representation of Sudoku.
// A storage type which contains size bits.
// We store a single value as a bitfield where its index is its value.
// We can use this to optimize for solving, as we can use bitwise operations to check for valid moves.
pub fn Board(comptime K: u16, comptime N: u16, comptime storage: SudokuStorage, comptime memory: SudokuMemory) type {
    const BitFieldType = SudokuBitFieldType(K, N);
    const ValueRangeType = SudokuValueRangeType(K, N);
    const ValidationErrorType = SudokuValidationError(ValueRangeType);

    const StorageImplType = if (storage == .BITFIELD) BitFieldType else ValueRangeType;

    const size = comptime @bitSizeOf(BitFieldType);

    const BoardType = switch (memory) {
        .STACK => [size * size]StorageImplType,
        .HEAP => []StorageImplType,
    };

    return struct {
        const Self = @This();

        allocator: ?*std.mem.Allocator,
        board: BoardType,
        size: usize,
        k: usize,
        n: usize,

        pub fn init(allocator: ?*std.mem.Allocator) Self {
            const board = switch (memory) {
                .STACK => [_]StorageImplType{SudokuEmptySentinel} ** (size * size),
                .HEAP => allocator.?.alloc(StorageImplType, size * size) catch |err| {
                    @panic(@errorName(err));
                },
            };

            if (memory == .HEAP) {
                @memset(board, SudokuEmptySentinel);
            }

            return Self{
                .allocator = allocator,
                .board = board,
                .size = size,
                .k = K,
                .n = N,
            };
        }

        pub fn deinit(self: *Self) void {
            if (memory == .HEAP) {
                if (self.allocator != null) {
                    self.allocator.?.free(self.board);
                } else {
                    @panic("No allocator provided");
                }
            }
        }

        /// Get the value of the field at i, j.
        pub fn get(self: *const Self, coordinate: SudokuCoordinate) ValueRangeType {
            const field = self.board[coordinate.i * self.size + coordinate.j];

            switch (storage) {
                .BITFIELD => {
                    if (field == SudokuEmptySentinel) {
                        return SudokuEmptySentinel;
                    }

                    return @intCast(@ctz(field) + 1);
                },
                .MATRIX => return field,
            }
        }

        /// Set the value of the field at i, j to value.
        pub fn set(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            assert(value <= self.size);

            const index = coordinate.i * self.size + coordinate.j;

            switch (storage) {
                .BITFIELD => {
                    // Ignore the previous value as we are setting a new value.
                    // We set value - 1 as the bit field is 0 indexed.
                    // The index 0 (first bit) is the first value.
                    if (value == SudokuEmptySentinel) {
                        self.board[index] = SudokuEmptySentinel;
                        return;
                    }

                    self.board[index] = 0 | @shlExact(@as(BitFieldType, 1), value - 1);
                },
                .MATRIX => {
                    self.board[index] = value;
                },
            }
        }

        pub fn clear(self: *Self) void {
            switch (storage) {
                .BITFIELD => {
                    for (0..self.size * self.size) |i| {
                        self.board[i] = SudokuEmptySentinel;
                    }
                },
                .MATRIX => {
                    @memset(self.board, SudokuEmptySentinel);
                },
            }
        }

        /// Access a constraint based on its index
        /// So row N, col N or grid N.
        pub fn index_iterator(self: *Self, comptime C: SudokuContraint, constraint_index: usize) SudokuContraintIterator(C) {
            return SudokuContraintIterator(C).initIndex(self, constraint_index);
        }

        /// Access the constraint based on any value from inside of it.
        /// Ei. coordinate X belongs to contraint N in row / col / grid.
        pub fn coord_iterator(self: *Self, comptime C: SudokuContraint, coord: SudokuCoordinate) SudokuContraintIterator(C) {
            return SudokuContraintIterator(C).init(self, coord);
        }

        /// Set entire row based on its index and a list of values.
        pub fn set_row(self: *Self, index: usize, values: [size]ValueRangeType) void {
            var it = self.index_iterator(.ROW, index);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        /// Set entire col based on its index and a list of values.
        pub fn set_col(self: *Self, index: usize, values: [size]ValueRangeType) void {
            var it = self.index_iterator(.COLUMN, index);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        /// Set entire grid based on its index and a list of values.
        pub fn set_grid(self: *Self, index: usize, values: [N * N]ValueRangeType) void {
            var it = self.index_iterator(.GRID, index);

            for (0..(N * N)) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        /// Make a move, check if it's valid, if not roll it back.
        pub fn is_valid_then_set(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) bool {
            var is_valid = true;

            const prev = self.get(coordinate);

            self.set(coordinate, value);

            if (is_valid) {
                var it = self.coord_iterator(.ROW, coordinate);
                is_valid = is_valid and self.validate_iterator(.ROW, &it) == null;
            }

            if (is_valid) {
                var it = self.coord_iterator(.COLUMN, coordinate);
                is_valid = is_valid and self.validate_iterator(.COLUMN, &it) == null;
            }

            if (is_valid) {
                var it = self.coord_iterator(.GRID, coordinate);
                is_valid = is_valid and self.validate_iterator(.GRID, &it) == null;
            } else {
                // Rollback
                self.set(coordinate, prev);
            }

            return is_valid;
        }

        /// Check if constraint is valid, if not return the first invalid coordinate.
        /// This decides how many errors we generate, if we want to show ALL incompatible
        /// positions we have to change it here.
        fn validate_iterator(self: *Self, comptime C: SudokuContraint, it: *SudokuContraintIterator(C)) ?ValidationErrorType {
            // Find coordinate based on constraint and index, then use iterator to get
            // every coordinate in that constraint and check for item uniqueness with get.
            switch (storage) {
                .BITFIELD => {
                    var field: BitFieldType = SudokuEmptySentinel;

                    while (it.next()) |current| {
                        const coordinate_field = self.board[current.i * self.size + current.j];

                        if (field & coordinate_field != 0) {
                            return ValidationErrorType{ .coordinate = current, .value = self.get(current) };
                        }

                        field |= coordinate_field;
                    }
                },
                .MATRIX => {
                    var seen = [_]bool{false} ** (size + 1);

                    while (it.next()) |current| {
                        const value = self.get(current);

                        if (value == SudokuEmptySentinel) {
                            continue;
                        }

                        if (seen[value]) {
                            return ValidationErrorType{ .coordinate = current, .value = value };
                        }

                        seen[value] = true;
                    }
                },
            }

            return null;
        }

        /// TODO Sudoku Constraint + index should probably be collected as a struct / tuple
        pub fn validate(self: *Self, comptime C: SudokuContraint, index: usize) ?ValidationErrorType {
            var it = self.index_iterator(C, index);
            return self.validate_iterator(C, &it);
        }

        /// Caller needs to deallocate result.
        /// Should probably extract return type into its own struct
        /// to enforce alloc + dealloc.
        pub fn validate_all(self: *Self, allocator: std.mem.Allocator) !std.EnumArray(SudokuContraint, std.ArrayList(ValidationErrorType)) {
            var row_errors = std.ArrayList(ValidationErrorType).init(allocator);
            var column_errors = std.ArrayList(ValidationErrorType).init(allocator);
            var grid_errors = std.ArrayList(ValidationErrorType).init(allocator);

            errdefer {
                row_errors.deinit();
                column_errors.deinit();
                grid_errors.deinit();
            }

            for (0..self.size) |i| {
                if (self.validate(.ROW, i)) |e| {
                    try row_errors.append(e);
                }
            }

            for (0..self.size) |i| {
                if (self.validate(.COLUMN, i)) |e| {
                    try column_errors.append(e);
                }
            }

            for (0..self.k * self.k) |i| {
                if (self.validate(.GRID, i)) |e| {
                    try grid_errors.append(e);
                }
            }

            return std.EnumArray(SudokuContraint, std.ArrayList(ValidationErrorType)).init(.{
                .ROW = row_errors,
                .COLUMN = column_errors,
                .GRID = grid_errors,
            });
        }

        /// Random fill, not real puzzle generation.
        pub fn fill_random_valid(self: *Self, attemps: usize, rng: *std.Random) void {
            for (0..attemps) |_| {
                const row = rng.intRangeLessThan(usize, 0, self.size);
                const col = rng.intRangeLessThan(usize, 0, self.size);
                const coord = SudokuCoordinate{ .i = row, .j = col };
                const value = rng.intRangeLessThan(ValueRangeType, 1, @as(ValueRangeType, @intCast(self.size + 1)));

                _ = self.is_valid_then_set(coord, value);
            }
        }

        /// Debug function to print board.
        pub fn display(self: *const Self, writer: anytype) !void {
            // Format in correct grid squares.
            // Border with | and -.

            const min_text_width = std.math.log10(self.size + 1) + 1;
            const line_width = K * N * (min_text_width + 3) + 1;

            for (0..self.size) |i| {
                if (i % self.n == 0) {
                    for (0..line_width) |_| {
                        _ = try writer.write("-");
                    }
                    _ = try writer.write("\n");
                }

                for (0..self.size) |j| {
                    const value = self.get(.{ .i = i, .j = j });

                    if (j == 0) {
                        _ = try writer.write("|");
                    }

                    const text_width = if (value == SudokuEmptySentinel) 1 else std.math.log10(value) + 1;
                    const spaces = if (min_text_width - text_width <= 0) 1 else min_text_width - text_width;

                    for (0..spaces) |_| {
                        _ = try writer.write(" ");
                    }

                    if (value == SudokuEmptySentinel) {
                        _ = try writer.write("?");
                    } else {
                        _ = try writer.print("{d}", .{value});
                    }

                    if ((j + 1) % self.n == 0) {
                        _ = try writer.write(" |");
                    }
                }

                _ = try writer.write("\n");

                if (i == self.size - 1) {
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
    _ = Board(2, 2, .BITFIELD, .STACK);
    _ = Board(3, 3, .BITFIELD, .STACK);
}

test "Test 4x4 Sudoku" {
    // Also test memory leaks.
    const S = Board(2, 2, .BITFIELD, .HEAP);

    var allocator = std.testing.allocator;
    var s = S.init(&allocator);
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
    const S = Board(3, 3, .BITFIELD, .STACK);

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
    const S = Board(32, 32, .MATRIX, .STACK);

    var s = S.init(null);

    s.set(.{ .i = 999, .j = 999 }, 1000);

    try expect(s.get(.{ .i = 999, .j = 999 }) == 1000);
}

test "Sudoku validation" {
    var sb = Board(3, 1, .BITFIELD, .STACK).init(null);

    sb.set_row(0, .{ 1, 2, 3 });

    try expect(sb.validate(.ROW, 0) == null);

    sb.set_col(0, .{ 1, 2, 1 });

    try expect(sb.validate(.COLUMN, 0) != null);

    sb.set(.{ .i = 2, .j = 0 }, 3);

    try expect(sb.validate(.COLUMN, 0) == null);

    sb.set(.{ .i = 0, .j = 0 }, 1);

    // Test basic matrix validation
    var sm = Board(3, 1, .MATRIX, .STACK).init(null);

    sm.set_row(0, .{ 1, 2, 3 });

    try expect(sm.validate(.ROW, 0) == null);

    sm.set_col(0, .{ 1, 1, 1 });

    try expect(sm.validate(.COLUMN, 0) != null);
}

pub fn from_stencil(stencil: []const u8, comptime k: u16, comptime n: u16, comptime S: SudokuStorage, allocator: *std.mem.Allocator) Board(
    k,
    n,
    S,
    .HEAP,
) {
    const SudokuT = Board(k, n, S, .HEAP);
    const ValueRangeType = SudokuValueRangeType(k, n);

    var s = SudokuT.init(allocator);

    for (0..stencil.len) |i| {
        const value = stencil[i];

        switch (value) {
            '.' => s.set(.{ .i = i / s.size, .j = i % s.size }, 0),
            else => {
                // value is u8, make into ValueRangeType by casting
                const val: ValueRangeType = @as(ValueRangeType, @intCast(value - '0'));

                s.set(.{ .i = i / s.size, .j = i % s.size }, val);
            },
        }
    }

    return s;
}

pub fn to_stencil(s: anytype, allocator: *std.mem.Allocator) []u8 {
    const size = s.size;
    const stencil = allocator.alloc(u8, size * size) catch |err| {
        @panic(@errorName(err));
    };

    for (0..size * size) |i| {
        const value = s.get(.{ .i = i / size, .j = i % size });

        stencil[i] = if (value == 0) '.' else '0' + @as(u8, value);
    }

    return stencil;
}

test "9x9 Stencil" {
    const stencil = ".................1.....2.3...2...4....3.5......41....6.5.6......7.....2..8.91....";
    var alloc = std.testing.allocator;
    var sudoku = from_stencil(stencil, 3, 3, .BITFIELD, &alloc);
    defer sudoku.deinit();

    const stencil_res = to_stencil(sudoku, &alloc);
    try expect(std.mem.eql(u8, stencil_res, stencil));
    alloc.free(stencil_res);
}
