const std = @import("std");
const Coordinate = @import("./Coordinate.zig");
const board = @import("./board.zig");

pub fn Sudoku(comptime K: usize, comptime N: u16) type {
    return struct {
        const Self = @This();
        const Storage = board.StorageType(K, N);

        board: *anyopaque,
        board_deinit: *const fn (*anyopaque) void,
        board_data_size: usize,
        board_get: *const fn (*anyopaque, Coordinate) Storage.ValueType,
        board_set: *const fn (*anyopaque, Coordinate, Storage.ValueType) void,
        board_clear: *const fn (*anyopaque) void,
        // The rest of the functions are not so important rn.
        // board_index_iterator: *const fn (*anyopaque, comptime C: SudokuContraint, usize) SudokuContraintIterator,
        // board_coord_iterator: *const fn (*anyopaque, comptime C: SudokuContraint, Coordinate) SudokuContraintIterator,
        board_set_row: *const fn (*anyopaque, usize, []Storage.ValueType) void,
        board_set_col: *const fn (*anyopaque, usize, []Storage.ValueType) void,
        board_set_grid: *const fn (*anyopaque, usize, []Storage.ValueType) void,

        /// Allocate the board with a layout, memory and allocator.
        pub fn initBoard(comptime S: board.StorageLayout, comptime M: board.StorageMemory, allocator: ?*std.mem.Allocator) Self {
            var b = board.Board(K, N, S, M).init(allocator);
            return Self.init(&b);
        }

        /// Use an existing board to create a Sudoku.
        /// TODO: Maybe swap names since initBoard requires the defer deinit call not init.
        pub fn init(b: anytype) Self {
            const T = @TypeOf(b.*);

            return Self{
                .board = @ptrCast(b),
                .board_deinit = @ptrCast(&T.deinit),
                .board_data_size = @bitSizeOf(T.Storage.BitFieldType),
                .board_get = @ptrCast(&T.get),
                .board_set = @ptrCast(&T.set),
                .board_clear = @ptrCast(&T.clear),
                //.board_index_iterator = @ptrCast(&T.index_iterator),
                //.board_coord_iterator = @ptrCast(&T.coord_iterator),
                .board_set_row = @ptrCast(&T.set_row),
                .board_set_col = @ptrCast(&T.set_col),
                .board_set_grid = @ptrCast(&T.set_grid),
            };
        }

        pub fn deinit(self: *Self) void {
            self.board_deinit(self.board);
        }

        pub fn get_board(self: *Self, comptime S: board.StorageLayout, comptime M: board.StorageMemory) *board.Board(K, N, S, M) {
            return @as(*board.Board(K, N, S, M), self.board);
        }

        pub fn get(self: *const Self, coord: Coordinate) Storage.ValueType {
            return self.board_get(self.board, coord);
        }

        pub fn set(self: *const Self, coord: Coordinate, value: Storage.ValueType) void {
            self.board_set(self.board, coord, value);
        }

        pub fn clear(self: *const Self) void {
            self.board_clear(self.board);
        }

        pub fn set_row(self: *const Self, index: usize, values: []Storage.ValueType) void {
            self.board_set_row(self.board, index, values);
        }

        pub fn set_col(self: *const Self, index: usize, values: []Storage.ValueType) void {
            self.board_set_col(self.board, index, values);
        }

        pub fn set_grid(self: *const Self, index: usize, values: []Storage.ValueType) void {
            self.board_set_grid(self.board, index, values);
        }
    };
}

test "Type errasure" {
    const Sudoku3x3 = board.Board(3, 3, .MATRIX, .STACK);
    var s = Sudoku3x3.init(null);
    const c = Coordinate{ .i = 0, .j = 0 };

    const a = Sudoku(3, 3).init(&s);

    a.set(c, 9);

    try std.testing.expect(s.get(c) == 9);
    try std.testing.expect(@as(u4, @intCast(a.get(c))) == 9);
}
