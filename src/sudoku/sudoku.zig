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

fn SudokuContraintIterator(comptime T: type, comptime C: SudokuContraint) type {
    switch (C) {
        .ROW => {
            return struct {
                start: SudokuCoordinate,
                end: SudokuCoordinate,
                sudoku: *const T,

                pub fn init(sudoku: *const T, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.size);
                    const coord = .{ .i = constraint_index, .j = 0 };

                    return @This(){
                        .start = .{ .i = coord.i, .j = 0 },
                        .end = .{ .i = coord.i, .j = sudoku.size },
                        .sudoku = sudoku,
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
                sudoku: *const T,

                pub fn init(sudoku: *const T, constraint_index: usize) @This() {
                    // The size of the sudoku is the same as the row column count.
                    assert(constraint_index < sudoku.size);

                    const coord = .{ .i = 0, .j = constraint_index };

                    return @This(){
                        .start = .{ .i = 0, .j = coord.j },
                        .end = .{ .i = sudoku.size, .j = coord.j },
                        .sudoku = sudoku,
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
                sudoku: *const T,
                done: bool,

                pub fn init(sudoku: *const T, constraint_index: usize) @This() {
                    assert(constraint_index < sudoku.grid_count);
                    const coord = .{ .i = (constraint_index / sudoku.grid_size) * sudoku.grid_size, .j = (constraint_index % sudoku.grid_size) * sudoku.grid_size };

                    return @This(){
                        .start = .{ .i = coord.i - (coord.i % sudoku.grid_size), .j = coord.j - (coord.j % sudoku.grid_size) },
                        .end = .{ .i = coord.i - (coord.i % sudoku.grid_size) + sudoku.grid_size - 1, .j = coord.j - (coord.j % sudoku.grid_size) + sudoku.grid_size - 1 },
                        .sudoku = sudoku,
                        .done = false,
                    };
                }

                pub fn next(self: *@This()) ?SudokuCoordinate {
                    if (self.done) {
                        return null;
                    }

                    const current = self.start;

                    if (current.equals(self.end)) {
                        self.done = true;
                        return self.end;
                    }

                    if (self.start.j == self.end.j) {
                        self.start.j = self.end.j - (self.sudoku.grid_size - 1);
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
fn SudokuBitFieldType(comptime k: u16, comptime n: u16) type {
    const size = k * n;
    const grid_size = pow(usize, n, 2);

    // assert sudoku is of valid size
    // n ** 2 has be equal to the length of the diagonal.
    if (size < grid_size) {
        @compileError(std.fmt.comptimePrint("Row and column have {d} inputs but the {d}x{d} grid has {d}\n", .{ size, n, n, grid_size }));
    }

    return std.meta.Int(.unsigned, size);
}

fn SudokuValueRangeType(comptime k: u16, comptime n: u16) type {
    return std.meta.Int(.unsigned, @bitSizeOf(usize) - @clz(@as(usize, @max(@bitSizeOf(SudokuBitFieldType(k, n)) - 1, 0))));
}

fn SudokuValidationError(comptime T: type) type {
    return struct {
        constraint_index: usize,
        coordinate: SudokuCoordinate,
        value: T,
    };
}

// Internal representation of Sudoku.
// A storage type which contains size bits.
// We store a single value as a bitfield where its index is its value.
// We can use this to optimize for solving, as we can use bitwise operations to check for valid moves.
pub fn Sudoku(comptime k: u16, comptime n: u16, comptime storage: SudokuStorage, comptime memory: SudokuMemory) type {
    const BitFieldType = SudokuBitFieldType(k, n);
    const ValueRangeType = SudokuValueRangeType(k, n);
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
        grid_size: usize,
        grid_count: usize,

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
                .grid_size = n,
                .grid_count = k * k,
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

        // Matrix getters and setters
        fn mget(self: *const Self, coordinate: SudokuCoordinate) ValueRangeType {
            return self.board[coordinate.i * self.size + coordinate.j];
        }

        fn mset(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            assert(value <= self.size);
            self.board[coordinate.i * self.size + coordinate.j] = value;
        }

        // Bitfield getters and setters
        fn bget(self: *const Self, coordinate: SudokuCoordinate) ValueRangeType {
            const field = self.board[coordinate.i * self.size + coordinate.j];

            if (field == SudokuEmptySentinel) {
                return SudokuEmptySentinel;
            }

            return @intCast(@ctz(field) + 1);
        }

        fn bset(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            assert(value <= self.size);

            // Ignore the previous value as we are setting a new value.
            // We set value - 1 as the bit field is 0 indexed.
            // The index 0 (first bit) is the first value.
            if (value == SudokuEmptySentinel) {
                self.board[coordinate.i * self.size + coordinate.j] = SudokuEmptySentinel;
                return;
            }

            self.board[coordinate.i * self.size + coordinate.j] = 0 | @shlExact(@as(BitFieldType, 1), value - 1);
        }

        // Get the value of the field at i, j.
        pub fn get(self: *const Self, coordinate: SudokuCoordinate) ValueRangeType {
            switch (storage) {
                .BITFIELD => return self.bget(coordinate),
                .MATRIX => return self.mget(coordinate),
            }
        }

        // Set the value of the field at i, j to value.
        pub fn set(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            switch (storage) {
                .BITFIELD => self.bset(coordinate, value),
                .MATRIX => self.mset(coordinate, value),
            }
        }

        pub fn set_row(self: *Self, index: usize, values: [size]ValueRangeType) void {
            var it = self.iterator(.ROW, index);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        pub fn set_col(self: *Self, index: usize, values: [size]ValueRangeType) void {
            var it = self.iterator(.COLUMN, index);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        pub fn set_grid(self: *Self, index: usize, values: [n * n]ValueRangeType) void {
            var it = self.iterator(.GRID, index);

            for (0..(n * n)) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        pub fn validate_all(self: *Self, allocator: std.mem.Allocator) !std.EnumArray(SudokuContraint, std.ArrayList(ValidationErrorType)) {
            var row_errors = std.ArrayList(ValidationErrorType).init(allocator);
            var column_errors = std.ArrayList(ValidationErrorType).init(allocator);
            var grid_errors = std.ArrayList(ValidationErrorType).init(allocator);

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

            for (0..self.grid_count) |i| {
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

        // Check if constraint is valid, if not returnt the first invalid coordinate.
        pub fn validate(self: *Self, comptime C: SudokuContraint, constraint_index: usize) ?ValidationErrorType {
            // Find coordinate based on constraint and index, then use iterator to get
            // every coordinate in that constraint and check for item uniqueness with get.
            var it = self.iterator(C, constraint_index);

            switch (storage) {
                .BITFIELD => {
                    var field: BitFieldType = SudokuEmptySentinel;

                    while (it.next()) |current| {
                        const coordinate_field = self.board[current.i * self.size + current.j];

                        if (field & coordinate_field != 0) {
                            return ValidationErrorType{ .constraint_index = constraint_index, .coordinate = current, .value = self.bget(current) };
                        }

                        field |= coordinate_field;
                    }
                },
                .MATRIX => {
                    var seen = [_]bool{false} ** (size + 1);

                    while (it.next()) |current| {
                        const value = self.mget(current);

                        if (value == SudokuEmptySentinel) {
                            continue;
                        }

                        if (seen[value]) {
                            return ValidationErrorType{ .constraint_index = constraint_index, .coordinate = current, .value = value };
                        }

                        seen[value] = true;
                    }
                },
            }

            return null;
        }

        pub fn iterator(self: *Self, comptime C: SudokuContraint, constraint_index: usize) SudokuContraintIterator(Self, C) {
            return SudokuContraintIterator(Self, C).init(self, constraint_index);
        }

        pub fn display(self: *const Self, writer: anytype) !void {
            // Format in correct grid squares.
            // Border with | and -.
            for (0..self.size) |i| {
                for (0..self.size) |j| {
                    const value = self.get(.{ .i = i, .j = j });

                    if (j == 0) {
                        _ = try writer.write("| ");
                    }

                    if (value == SudokuEmptySentinel) {
                        _ = try writer.write("? ");
                    } else {
                        _ = try writer.print("{d} ", .{value});
                    }

                    if ((j + 1) % self.grid_size == 0) {
                        _ = try writer.write("| ");
                    }
                }

                _ = try writer.write("\n");
            }

            _ = try writer.write("\n");
        }
    };
}

test "Validate certain sudoku board sizes" {
    _ = Sudoku(2, 2, .BITFIELD, .STACK);
    _ = Sudoku(3, 3, .BITFIELD, .STACK);
}

test "Test 4x4 Sudoku" {
    // Also test memory leaks.
    const S = Sudoku(2, 2, .BITFIELD, .HEAP);

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

    var it_row = s.iterator(.ROW, 0);

    try expect(it_row.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 2 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 3 }));
    try expect(it_row.next() == null);

    var it_col = s.iterator(.COLUMN, 0);

    try expect(it_col.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 2, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 3, .j = 0 }));
    try expect(it_col.next() == null);

    var it_grid = s.iterator(.GRID, 0);

    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 1 }));
    try expect(it_grid.next() == null);
}

test "Test 9x9 Sudoku" {
    const S = Sudoku(3, 3, .BITFIELD, .STACK);

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

    var it_row = s.iterator(.ROW, 0);

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

    var it_col = s.iterator(.COLUMN, 0);

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

    var it_grid = s.iterator(.GRID, 0);

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
    const S = Sudoku(32, 32, .MATRIX, .STACK);

    var s = S.init(null);

    s.set(.{ .i = 999, .j = 999 }, 1000);

    try expect(s.get(.{ .i = 999, .j = 999 }) == 1000);
}

test "Sudoku validation" {
    var sb = Sudoku(3, 1, .BITFIELD, .STACK).init(null);

    sb.set_row(0, .{ 1, 2, 3 });

    try expect(sb.validate(.ROW, 0) == null);

    sb.set_col(0, .{ 1, 2, 1 });

    try expect(sb.validate(.COLUMN, 0) != null);

    sb.set(.{ .i = 2, .j = 0 }, 3);

    try expect(sb.validate(.COLUMN, 0) == null);

    sb.set(.{ .i = 0, .j = 0 }, 1);

    // Test basic matrix validation
    var sm = Sudoku(3, 1, .MATRIX, .STACK).init(null);

    sm.set_row(0, .{ 1, 2, 3 });

    try expect(sm.validate(.ROW, 0) == null);

    sm.set_col(0, .{ 1, 1, 1 });

    try expect(sm.validate(.COLUMN, 0) != null);
}

pub fn from_stencil(stencil: []const u8, comptime k: u16, comptime n: u16, comptime S: SudokuStorage, allocator: *std.mem.Allocator) Sudoku(
    k,
    n,
    S,
    .HEAP,
) {
    const SudokuT = Sudoku(k, n, S, .HEAP);
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
