const std = @import("std");
const Coordinate = @import("./Coordinate.zig");
const Board = @import("./board.zig").Board;

pub const Sudoku = struct {
    const Self = @This();

    board: *anyopaque,
    board_data_size: usize,
    board_get: *const fn (*anyopaque, Coordinate) usize,
    board_set: *const fn (*anyopaque, Coordinate, usize) void,
    board_clear: *const fn (*anyopaque) void,
    //board_index_iterator: *const fn (*anyopaque, comptime C: SudokuContraint, usize) SudokuContraintIterator,
    //board_coord_iterator: *const fn (*anyopaque, comptime C: SudokuContraint, Coordinate) SudokuContraintIterator,
    board_set_row: *const fn (*anyopaque, usize, []usize) void,
    board_set_col: *const fn (*anyopaque, usize, []usize) void,
    board_set_grid: *const fn (*anyopaque, usize, []usize) void,
    board_is_valid_then_set: *const fn (*anyopaque, Coordinate, usize) bool,
    // The rest of the functions are not so important rn.

    pub fn init(board: anytype) Self {
        const T = @TypeOf(board.*);

        return Self{
            .board = @ptrCast(board),
            .board_data_size = @bitSizeOf(T.Storage.BitFieldType),
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

    pub fn get(self: *const Self, coord: Coordinate) usize {
        return self.board_get(self.board, coord);
    }

    pub fn set(self: *const Self, coord: Coordinate, value: usize) void {
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

    pub fn is_valid_then_set(self: *const Self, coord: Coordinate, value: usize) bool {
        return self.board_is_valid_then_set(self.board, coord, value);
    }
};

test "Type errasure" {
    const Sudoku3x3 = Board(3, 3, .MATRIX, .STACK);
    var s = Sudoku3x3.init(null);
    const c = Coordinate{ .i = 0, .j = 0 };

    const a = Sudoku.init(&s);

    a.set(c, 9);

    std.log.warn("\nValue of s: {d}\nValue of a: {d}\n", .{ s.get(c), a.get(c) });

    try std.testing.expect(s.get(c) == 9);
    try std.testing.expect(@as(u4, @intCast(a.get(c))) == 9);
}
