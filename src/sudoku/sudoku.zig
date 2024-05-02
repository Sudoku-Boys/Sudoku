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
        .COLUMN => {
            return struct {
                start: SudokuCoordinate,
                end: SudokuCoordinate,
                sudoku: *const T,

                pub fn init(sudoku: *const T, any: SudokuCoordinate) @This() {
                    return @This(){
                        .start = .{ .i = 0, .j = any.j },
                        .end = .{ .i = sudoku.size, .j = any.j },
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
        .ROW => {
            return struct {
                start: SudokuCoordinate,
                end: SudokuCoordinate,
                sudoku: *const T,

                pub fn init(sudoku: *const T, any: SudokuCoordinate) @This() {
                    return @This(){
                        .start = .{ .i = any.i, .j = 0 },
                        .end = .{ .i = any.i, .j = sudoku.size },
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
        .GRID => {
            return struct {
                start: SudokuCoordinate,
                end: SudokuCoordinate,
                sudoku: *const T,
                done: bool,

                pub fn init(sudoku: *const T, any: SudokuCoordinate) @This() {
                    return @This(){
                        .start = .{ .i = any.i - (any.i % sudoku.grid_size), .j = any.j - (any.j % sudoku.grid_size) },
                        .end = .{ .i = any.i - (any.i % sudoku.grid_size) + sudoku.grid_size - 1, .j = any.j - (any.j % sudoku.grid_size) + sudoku.grid_size - 1 },
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
    const grid_size = pow(u64, n, 2);

    // assert sudoku is of valid size
    // n ** 2 has be equal to the length of the diagonal.
    if (size < grid_size) {
        @compileError(std.fmt.comptimePrint("Row and column have {d} inputs but the {d}x{d} grid has {d}\n", .{ size, n, n, grid_size }));
    }

    // The
    return std.meta.Int(.unsigned, size);
}

fn SudokuValueRangeType(comptime k: u16, comptime n: u16) type {
    return std.meta.Int(.unsigned, 64 - @clz(@as(u64, @max(@bitSizeOf(SudokuBitFieldType(k, n)) - 1, 0))));
}

// Internal representation of Sudoku.
// A storage type which contains size bits.
// We store a single value as a bitfield where its index is its value.
// We can use this to optimize for solving, as we can use bitwise operations to check for valid moves.
pub fn Sudoku(comptime k: u16, comptime n: u16, comptime storageType: SudokuStorage, comptime memoryType: SudokuMemory) type {
    const BitFieldType = SudokuBitFieldType(k, n);

    const size = comptime @bitSizeOf(BitFieldType);

    const ValueRangeType = SudokuValueRangeType(k, n);

    const StorageImplType = if (storageType == .BITFIELD) BitFieldType else ValueRangeType;

    const BoardType = switch (memoryType) {
        .STACK => [size * size]StorageImplType,
        .HEAP => []StorageImplType,
    };

    return struct {
        const Self = @This();

        size: usize,
        grid_size: usize,
        board: BoardType,
        alloc: ?*std.mem.Allocator,
        pub fn init(alloc: ?*std.mem.Allocator) Self {
            const s = Self{
                .board = switch (memoryType) {
                    .STACK => [_]StorageImplType{SudokuEmptySentinel} ** (size * size),
                    .HEAP => alloc.?.alloc(StorageImplType, size * size) catch |err| {
                        @panic(@errorName(err));
                    },
                },
                .size = size,
                .grid_size = n,
                .alloc = alloc,
            };

            if (memoryType == .HEAP) {
                @memset(s.board, SudokuEmptySentinel);
            }

            return s;
        }

        pub fn deinit(self: *Self) void {
            if (memoryType == .HEAP) {
                if (self.alloc != null) {
                    self.alloc.?.free(self.board);
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
            switch (storageType) {
                .BITFIELD => return self.bget(coordinate),
                .MATRIX => return self.mget(coordinate),
            }
        }

        // Set the value of the field at i, j to value.
        pub fn set(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            switch (storageType) {
                .BITFIELD => self.bset(coordinate, value),
                .MATRIX => self.mset(coordinate, value),
            }
        }

        fn get_initial_constraint_coordinate(self: *Self, comptime C: SudokuContraint, constraint_index: u8) SudokuCoordinate {
            return switch (C) {
                .ROW => .{ .i = constraint_index, .j = 0 },
                .COLUMN => .{ .i = 0, .j = constraint_index },
                .GRID => .{ .i = (constraint_index / self.grid_size) * self.grid_size, .j = (constraint_index % self.grid_size) * self.grid_size },
            };
        }

        pub fn set_row(self: *Self, index: u8, values: [size]ValueRangeType) void {
            const coordinate = self.get_initial_constraint_coordinate(.ROW, index);
            var it = self.iterator(.ROW, coordinate);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        pub fn set_col(self: *Self, index: u8, values: [size]ValueRangeType) void {
            const coordinate = self.get_initial_constraint_coordinate(.COLUMN, index);
            var it = self.iterator(.COLUMN, coordinate);

            for (0..size) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        pub fn set_grid(self: *Self, index: u8, values: [n * n]ValueRangeType) void {
            const coordinate = self.get_initial_constraint_coordinate(.GRID, index);
            var it = self.iterator(.GRID, coordinate);

            for (0..(n * n)) |i| {
                self.set(it.next().?, values[i]);
            }
        }

        // Check
        pub fn validate(self: *Self, comptime C: SudokuContraint, constraint_index: u8) bool {
            // Find coordinate based on constraint and index, then use iterator to get
            // every coordinate in that constraint and check for item uniqueness with get.
            const coordinate = self.get_initial_constraint_coordinate(C, constraint_index);

            var it = self.iterator(C, coordinate);

            switch (storageType) {
                .BITFIELD => {
                    var field: BitFieldType = SudokuEmptySentinel;

                    while (it.next()) |current| {
                        const coordinate_field = self.board[current.i * self.size + current.j];

                        if (field & coordinate_field != 0) {
                            return false;
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

                        if (seen[value] != false) {
                            return false;
                        }

                        seen[value] = true;
                    }
                },
            }

            return true;
        }

        pub fn iterator(self: *Self, comptime C: SudokuContraint, coordinate: SudokuCoordinate) SudokuContraintIterator(Self, C) {
            return SudokuContraintIterator(Self, C).init(self, coordinate);
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

    var it_row = s.iterator(.ROW, .{ .i = 0, .j = 0 });

    try expect(it_row.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 2 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 3 }));
    try expect(it_row.next() == null);

    var it_col = s.iterator(.COLUMN, .{ .i = 0, .j = 0 });

    try expect(it_col.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 2, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 3, .j = 0 }));
    try expect(it_col.next() == null);

    var it_grid = s.iterator(.GRID, .{ .i = 0, .j = 0 });

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

    var it_row = s.iterator(.ROW, .{ .i = 0, .j = 0 });

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

    var it_col = s.iterator(.COLUMN, .{ .i = 0, .j = 0 });

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

    var it_grid = s.iterator(.GRID, .{ .i = 0, .j = 0 });

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

    try expect(sb.validate(.ROW, 0));

    sb.set_col(0, .{ 1, 2, 1 });

    try expect(sb.validate(.COLUMN, 0) == false);

    sb.set(.{ .i = 2, .j = 0 }, 3);

    try expect(sb.validate(.COLUMN, 0));

    sb.set(.{ .i = 0, .j = 0 }, 1);

    // Test basic matrix validation
    var sm = Sudoku(3, 1, .MATRIX, .STACK).init(null);

    sm.set_row(0, .{ 1, 2, 3 });

    try expect(sm.validate(.ROW, 0));

    sm.set_col(0, .{ 1, 1, 1 });

    try expect(sm.validate(.COLUMN, 0) == false);
}

pub fn from_stencil(stencil: []const u8, comptime k: u16, comptime n: u16, comptime S: SudokuStorage, alloc: *std.mem.Allocator) Sudoku(
    k,
    n,
    S,
    .HEAP,
) {
    const SudokuT = Sudoku(k, n, S, .HEAP);
    const ValueRangeType = SudokuValueRangeType(k, n);

    var s = SudokuT.init(alloc);

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

pub fn to_stencil(s: anytype, alloc: *std.mem.Allocator) []u8 {
    const size = s.size;
    const stencil = alloc.alloc(u8, size * size) catch |err| {
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
