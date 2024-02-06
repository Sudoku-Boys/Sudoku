const std = @import("std");
const pow = std.math.pow;
const assert = std.debug.assert;
const expect = std.testing.expect;

// Infer size of type to fit valid sudoku.
// From description.
fn SudokuBitFieldType(comptime k: u16, comptime n: u16) type {
    // assert sudoku is of valid size
    // n ** 2 has be equal to the length of the diagonal.
    if (pow(u64, n, 2) < k * n) {
        @compileError(std.fmt.comptimePrint("N of value {d} is too small since it provides only {d} numbers but requires {d}\n", .{ n, pow(u64, n, 2), k * n }));
    }

    return std.meta.Int(.unsigned, k * n);
}

pub const SudokuContraint = enum { ROW, COLUMN, GRID };
pub const SudokuStorage = enum { BITFIELD, MATRIX };
pub const SudokuMemory = enum { STACK, HEAP };

pub const SudokuCoordinate = struct {
    i: usize,
    j: usize,

    pub fn equals(self: SudokuCoordinate, other: SudokuCoordinate) bool {
        return self.i == other.i and self.j == other.j;
    }
};

pub fn SudokuContraintIterator(comptime T: type, comptime C: SudokuContraint) type {
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

// Internal representation of Sudoku.
// A storage type which contains size bits.
// We store a single value as a bitfield where its index is its value.
// We can use this to optimize for solving, as we can use bitwise operations to check for valid moves.
pub fn Sudoku(comptime K: u16, comptime N: u16, comptime S: SudokuStorage, comptime M: SudokuMemory) type {
    const BitFieldType = SudokuBitFieldType(K, N);

    const size = comptime @bitSizeOf(BitFieldType);

    const ValueRangeType = comptime std.meta.Int(.unsigned, 64 - @clz(@as(u64, @max(size - 1, 0))));

    const StorageImplType = if (S == .BITFIELD) BitFieldType else ValueRangeType;

    const BoardType = switch (M) {
        .STACK => [size * size]StorageImplType,
        .HEAP => []StorageImplType,
    };

    return struct {
        const Self = @This();

        size: usize,
        grid_size: usize,
        board: BoardType,

        pub fn init(alloc: ?*std.mem.Allocator) Self {
            return Self{
                .board = switch (M) {
                    .STACK => undefined,
                    .HEAP => if (alloc != null) alloc.?.alloc(StorageImplType, size * size) catch |err| {
                        @panic(@errorName(err));
                    } else @panic("No allocator provided"),
                },
                .size = size,
                .grid_size = N,
            };
        }

        fn get_matrix(self: *const Self, coordinate: SudokuCoordinate) ValueRangeType {
            return self.board[coordinate.i * self.size + coordinate.j];
        }

        fn set_matrix(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            self.board[coordinate.i * self.size + coordinate.j] = value;
        }

        fn get_bitfield(self: *const Self, coordinate: SudokuCoordinate) ValueRangeType {
            const field = self.board[coordinate.i * self.size + coordinate.j];

            // Find index of the first set bit.
            var k: ValueRangeType = 0;

            while (k < self.size) {
                if (field & (@shlExact(@as(BitFieldType, 1), k)) != 0) {
                    return k;
                }

                k += 1;
            }

            return 0;
        }

        fn set_bitfield(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            assert(value < self.size);
            // Ignore the previous value as we are setting a new value.
            // Access field as mutable.
            self.board[coordinate.i * self.size + coordinate.j] = 0 | @shlExact(@as(BitFieldType, 1), value);
        }

        // Get the value of the field at i, j.
        pub fn get(self: *const Self, coordinate: SudokuCoordinate) ValueRangeType {
            switch (S) {
                .BITFIELD => return self.get_bitfield(coordinate),
                .MATRIX => return self.get_matrix(coordinate),
            }
        }

        // Set the value of the field at i, j to value.
        pub fn set(self: *Self, coordinate: SudokuCoordinate, value: ValueRangeType) void {
            switch (S) {
                .BITFIELD => self.set_bitfield(coordinate, value),
                .MATRIX => self.set_matrix(coordinate, value),
            }
        }
    };
}

// A Sudoku of any size, used for generic functions.
pub const AnySudoku = Sudoku(0, 0, .BITFIELD, .STACK);

test "Validate certain sudoku board sizes" {
    _ = Sudoku(2, 2, .BITFIELD, .STACK);
    _ = Sudoku(3, 3, .BITFIELD, .STACK);
}

test "Test 4x4 Sudoku" {
    const S = Sudoku(2, 2, .BITFIELD, .STACK);

    var s = S.init(null);

    // Get typeinfo of s.get returntype.
    // const a = @typeInfo(@TypeOf(s));
    // @compileLog(a.Struct.fields);

    s.set(.{ .i = 0, .j = 0 }, 1);
    s.set(.{ .i = 0, .j = 1 }, 2);
    s.set(.{ .i = 1, .j = 0 }, 3);
    s.set(.{ .i = 1, .j = 1 }, 0);

    try expect(s.get(.{ .i = 0, .j = 0 }) == 1);
    try expect(s.get(.{ .i = 0, .j = 1 }) == 2);
    try expect(s.get(.{ .i = 1, .j = 0 }) == 3);
    try expect(s.get(.{ .i = 1, .j = 1 }) == 0);

    var it_row = SudokuContraintIterator(S, .ROW).init(&s, .{ .i = 0, .j = 0 });

    try expect(it_row.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 2 }));
    try expect(it_row.next().?.equals(.{ .i = 0, .j = 3 }));
    try expect(it_row.next() == null);

    var it_col = SudokuContraintIterator(S, .COLUMN).init(&s, .{ .i = 0, .j = 0 });

    try expect(it_col.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 2, .j = 0 }));
    try expect(it_col.next().?.equals(.{ .i = 3, .j = 0 }));
    try expect(it_col.next() == null);

    var it_grid = SudokuContraintIterator(S, .GRID).init(&s, .{ .i = 0, .j = 0 });

    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 0, .j = 1 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 0 }));
    try expect(it_grid.next().?.equals(.{ .i = 1, .j = 1 }));
    try expect(it_grid.next() == null);
}

test "Test 9x9 Sudoku" {
    const S = Sudoku(3, 3, .BITFIELD, .STACK);

    var s = S.init(null);

    s.set(.{ .i = 0, .j = 0 }, 0);
    s.set(.{ .i = 0, .j = 1 }, 1);
    s.set(.{ .i = 0, .j = 2 }, 2);
    s.set(.{ .i = 0, .j = 3 }, 3);
    s.set(.{ .i = 0, .j = 4 }, 4);
    s.set(.{ .i = 0, .j = 5 }, 5);
    s.set(.{ .i = 0, .j = 6 }, 6);
    s.set(.{ .i = 0, .j = 7 }, 7);
    s.set(.{ .i = 0, .j = 8 }, 8);

    try expect(s.get(.{ .i = 0, .j = 0 }) == 0);
    try expect(s.get(.{ .i = 0, .j = 1 }) == 1);
    try expect(s.get(.{ .i = 0, .j = 2 }) == 2);
    try expect(s.get(.{ .i = 0, .j = 3 }) == 3);
    try expect(s.get(.{ .i = 0, .j = 4 }) == 4);
    try expect(s.get(.{ .i = 0, .j = 5 }) == 5);
    try expect(s.get(.{ .i = 0, .j = 6 }) == 6);
    try expect(s.get(.{ .i = 0, .j = 7 }) == 7);
    try expect(s.get(.{ .i = 0, .j = 8 }) == 8);

    var it_row = SudokuContraintIterator(S, .ROW).init(&s, .{ .i = 0, .j = 0 });

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

    var it_col = SudokuContraintIterator(S, .COLUMN).init(&s, .{ .i = 0, .j = 0 });

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

    var it_grid = SudokuContraintIterator(S, .GRID).init(&s, .{ .i = 0, .j = 0 });

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
    const S = Sudoku(10, 100, .MATRIX, .STACK);

    var s = S.init(null);

    s.set(.{ .i = 999, .j = 999 }, 999);

    try expect(s.get(.{ .i = 999, .j = 999 }) == 999);
}
