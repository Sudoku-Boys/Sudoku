const std = @import("std");
const pow = std.math.pow;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Coordinate = @import("Coordinate.zig");

pub const DefaultBoard = Board(3, 3, .MATRIX, .HEAP);

pub const BoardContraint = enum { ROW, COLUMN, GRID };
pub const StorageLayout = enum { BITFIELD, MATRIX };
pub const StorageMemory = enum { STACK, HEAP };
pub const EmptySentinel = 0;

/// TODO rewrite type.
fn BoardContraintIterator(comptime C: BoardContraint) type {
    switch (C) {
        .ROW => {
            return struct {
                start: Coordinate,
                end: Coordinate,

                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.size);
                    const coord = .{ .i = constraint_index, .j = 0 };
                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: Coordinate) @This() {
                    return @This(){
                        .start = .{ .i = coord.i, .j = 0 },
                        .end = .{ .i = coord.i, .j = sudoku.size },
                    };
                }

                pub fn next(self: *@This()) ?Coordinate {
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
                start: Coordinate,
                end: Coordinate,

                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    // The size of the sudoku is the same as the row column count.
                    assert(constraint_index < sudoku.size);
                    const coord = .{ .i = 0, .j = constraint_index };
                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: Coordinate) @This() {
                    return @This(){
                        .start = .{ .i = 0, .j = coord.j },
                        .end = .{ .i = sudoku.size, .j = coord.j },
                    };
                }

                pub fn next(self: *@This()) ?Coordinate {
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
                start: Coordinate,
                end: Coordinate,
                n: usize,
                done: bool,

                /// TODO: We started with init() only, so initIndex and init contain
                /// duplicate / negated logic. We should refactor this.
                pub fn initIndex(sudoku: anytype, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.k * sudoku.k);

                    const row = constraint_index / sudoku.k;
                    const col = constraint_index % sudoku.k;

                    const coord = .{ .i = row * sudoku.n, .j = col * sudoku.n };

                    return @This().init(sudoku, coord);
                }

                pub fn init(sudoku: anytype, coord: Coordinate) @This() {
                    return @This(){
                        .start = .{ .i = coord.i - (coord.i % sudoku.n), .j = coord.j - (coord.j % sudoku.n) },
                        .end = .{ .i = coord.i - (coord.i % sudoku.n) + sudoku.n - 1, .j = coord.j - (coord.j % sudoku.n) + sudoku.n - 1 },
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

fn SudokuValidationError(comptime T: type) type {
    return struct {
        coordinate: Coordinate,
        value: T,
    };
}

/// Infer size of type to fit valid sudoku. From description.
pub fn StorageType(comptime K: u16, comptime N: u16) type {
    const size = K * N;
    const area = pow(usize, N, 2);

    // assert sudoku is of valid size
    // n ** 2 has be equal to the length of the diagonal.
    if (size < area) {
        @compileError(std.fmt.comptimePrint("Row and column have {d} inputs but the {d}x{d} grid has {d}\n", .{ size, N, N, area }));
    }

    const value_size = @bitSizeOf(usize) - @clz(@as(usize, @max(size - 1, 0)));

    return struct {
        pub const ValueType = std.meta.Int(.unsigned, value_size);
        pub const BitFieldType = std.meta.Int(.unsigned, size);
    };
}

/// Internal representation of Sudoku.
/// A storage type which contains size bits.
/// We store a single value as a bitfield where its index is its value.
/// We can use this to optimize for solving, as we can use bitwise operations to check for valid moves.
/// TODO: Actually optimize bitfield storage to store multiple values in a single field.
pub fn Board(comptime K: u16, comptime N: u16, comptime storage: StorageLayout, comptime memory: StorageMemory) type {
    return struct {
        const Self = @This();

        pub const Storage = StorageType(K, N);
        pub const StorageImplType = if (storage == .BITFIELD) Storage.BitFieldType else Storage.ValueType;
        pub const ValidationErrorType = SudokuValidationError(Storage.ValueType);

        pub const size = @bitSizeOf(Storage.BitFieldType);

        pub const BoardType = switch (memory) {
            .STACK => [size * size]StorageImplType,
            .HEAP => []StorageImplType,
        };

        allocator: ?std.mem.Allocator,
        board: BoardType,
        size: usize,
        k: usize,
        n: usize,

        pub fn init(allocator: ?std.mem.Allocator) Self {
            const board = switch (memory) {
                .STACK => [_]StorageImplType{EmptySentinel} ** (size * size),
                .HEAP => allocator.?.alloc(StorageImplType, size * size) catch |err| {
                    @panic(@errorName(err));
                },
            };

            if (memory == .HEAP) {
                @memset(board, EmptySentinel);
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
        pub fn get(self: *const Self, coordinate: Coordinate) Storage.ValueType {
            assert(self.size == size);
            assert(coordinate.i < size and coordinate.j < size);

            const field = self.board[coordinate.i * size + coordinate.j];

            switch (storage) {
                .BITFIELD => {
                    if (field == EmptySentinel) {
                        return EmptySentinel;
                    }

                    return @intCast(@ctz(field) + 1);
                },
                .MATRIX => return field,
            }
        }

        /// Set the value of the field at i, j to value.
        pub fn set(self: *Self, coordinate: Coordinate, value: Storage.ValueType) void {
            assert(self.size == size);
            assert(value <= self.size and coordinate.i < size and coordinate.j < size);

            const index = coordinate.i * size + coordinate.j;

            switch (storage) {
                .BITFIELD => {
                    // Ignore the previous value as we are setting a new value.
                    // We set value - 1 as the bit field is 0 indexed.
                    // The index 0 (first bit) is the first value.
                    if (value == EmptySentinel) {
                        self.board[index] = EmptySentinel;
                        return;
                    }

                    self.board[index] = 0 | @shlExact(@as(Storage.BitFieldType, 1), value - 1);
                },
                .MATRIX => {
                    self.board[index] = value;
                },
            }
        }

        pub fn clear(self: *Self) void {
            switch (memory) {
                .STACK => {
                    for (0..size * size) |i| {
                        self.board[i] = EmptySentinel;
                    }
                },
                .HEAP => {
                    @memset(self.board, EmptySentinel);
                },
            }
        }

        /// Access a constraint based on its index
        /// So row N, col N or grid N.
        pub fn index_iterator(self: *Self, comptime C: BoardContraint, constraint_index: usize) BoardContraintIterator(C) {
            return BoardContraintIterator(C).initIndex(self, constraint_index);
        }

        /// Access the constraint based on any value from inside of it.
        /// Ei. coordinate X belongs to contraint N in row / col / grid.
        pub fn coord_iterator(self: *Self, comptime C: BoardContraint, coord: Coordinate) BoardContraintIterator(C) {
            return BoardContraintIterator(C).init(self, coord);
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

        /// TODO optimize this and is_safe_move when in bitfield mode.
        fn iterator_contains(self: *Self, iterator: anytype, value: Storage.ValueType) bool {
            while (iterator.next()) |current| {
                if (self.get(current) == value) {
                    return true;
                }
            }

            return false;
        }

        pub fn is_safe_move(self: *Self, coordinate: Coordinate, value: Storage.ValueType) bool {
            const current_value = self.get(coordinate);

            // Cannot set a field that is already set.
            // Maybe this should return true if the value is the same.
            // Most likely not.
            if (current_value != EmptySentinel) {
                return false;
            }

            // Loop over all constraints.
            var it_row = self.coord_iterator(.ROW, coordinate);
            if (self.iterator_contains(&it_row, value)) {
                return false;
            }

            var it_col = self.coord_iterator(.COLUMN, coordinate);
            if (self.iterator_contains(&it_col, value)) {
                return false;
            }

            var it_grid = self.coord_iterator(.GRID, coordinate);
            if (self.iterator_contains(&it_grid, value)) {
                return false;
            }

            return true;
        }

        pub fn get_possibility_count(self: *Self, coord: Coordinate) usize {
            var count: usize = 0;

            for (0..size) |i| {
                const v: Storage.ValueType = @intCast(i + 1);

                if (self.is_safe_move(coord, v)) {
                    count += 1;
                }
            }

            return count;
        }

        /// Get a list of all possible values for a coordinate.
        /// This is used for backtracking.
        pub fn get_possibilities(self: *Self, coord: Coordinate, allocator: std.mem.Allocator) ![]Storage.ValueType {
            var possibilities: []Storage.ValueType = try allocator.alloc(Storage.ValueType, size);

            for (0..size) |i| {
                const v: Storage.ValueType = @intCast(i + 1);

                if (!self.is_safe_move(coord, v)) {
                    possibilities[i] = EmptySentinel;
                } else {
                    possibilities[i] = v;
                }
            }

            return possibilities;
        }

        /// Check if constraint is valid, if not return the first invalid coordinate.
        /// This decides how many errors we generate, if we want to show ALL incompatible
        /// positions we have to change it here.
        fn validate_iterator(self: *Self, comptime C: BoardContraint, it: *BoardContraintIterator(C)) ?ValidationErrorType {
            // Find coordinate based on constraint and index, then use iterator to get
            // every coordinate in that constraint and check for item uniqueness with get.
            switch (storage) {
                .BITFIELD => {
                    var field: Storage.BitFieldType = EmptySentinel;

                    while (it.next()) |current| {
                        const coordinate_field = self.board[current.i * size + current.j];

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

                        if (value == EmptySentinel) {
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
        pub fn validate(self: *Self, comptime C: BoardContraint, index: usize) ?ValidationErrorType {
            var it = self.index_iterator(C, index);
            return self.validate_iterator(C, &it);
        }

        /// Caller needs to deallocate result.
        /// Should probably extract return type into its own struct
        /// to enforce alloc + dealloc.
        pub fn validate_all(self: *Self, allocator: std.mem.Allocator) !std.EnumArray(BoardContraint, std.ArrayList(ValidationErrorType)) {
            var row_errors = std.ArrayList(ValidationErrorType).init(allocator);
            var column_errors = std.ArrayList(ValidationErrorType).init(allocator);
            var grid_errors = std.ArrayList(ValidationErrorType).init(allocator);

            errdefer {
                row_errors.deinit();
                column_errors.deinit();
                grid_errors.deinit();
            }

            for (0..size) |i| {
                if (self.validate(.ROW, i)) |e| {
                    try row_errors.append(e);
                }
            }

            for (0..size) |i| {
                if (self.validate(.COLUMN, i)) |e| {
                    try column_errors.append(e);
                }
            }

            for (0..K * K) |i| {
                if (self.validate(.GRID, i)) |e| {
                    try grid_errors.append(e);
                }
            }

            return std.EnumArray(BoardContraint, std.ArrayList(ValidationErrorType)).init(.{
                .ROW = row_errors,
                .COLUMN = column_errors,
                .GRID = grid_errors,
            });
        }

        /// Random fill, not real puzzle generation.
        pub fn fill_random_valid(self: *Self, max_filled: usize, max_attemps: usize, rng: *std.Random) void {
            var succesful_fills: usize = 0;

            for (0..max_attemps) |_| {
                if (succesful_fills >= max_filled) {
                    break;
                }

                const coord = Coordinate.random(size, rng);

                const value = rng.intRangeLessThan(Storage.ValueType, 1, @as(Storage.ValueType, @intCast(size + 1)));

                if (self.is_safe_move(coord, value)) {
                    self.set(coord, value);
                    succesful_fills += 1;
                }
            }
        }

        /// Debug function to print board.
        pub fn display(self: *const Self, writer: anytype) !void {
            // Format in correct grid squares.
            // Border with | and -.
            var int_buf: [1]u8 = [_]u8{0};
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
    _ = Board(2, 2, .BITFIELD, .STACK);
    _ = Board(3, 3, .BITFIELD, .STACK);
}

test "Test 4x4 Sudoku" {
    // Also test memory leaks.
    const S = Board(2, 2, .BITFIELD, .HEAP);

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
