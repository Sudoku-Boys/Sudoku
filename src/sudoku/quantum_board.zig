const std = @import("std");
const Board = @import("board.zig");
const Coordinate = @import("Coordinate.zig");

const assert = std.debug.assert;
pub const EmptySentinel = 0;

pub fn QuantumBoard(comptime K: usize, comptime N: usize, comptime memory: Board.StorageMemory) type {
    return struct {
        const Self = @This();

        pub const StorageImplType = u64;

        pub const size = K * N;

        pub const BoardType = switch (memory) {
            .STACK => [size * size]StorageImplType,
            .HEAP => []StorageImplType,
        };

        pub const DefaultValue = (1 << N * K) - 1;

        allocator: ?std.mem.Allocator,
        board: BoardType,
        size: usize,
        k: usize,
        n: usize,

        pub fn init(allocator: ?std.mem.Allocator) Self {
            const board = switch (memory) {
                .STACK => [_]StorageImplType{DefaultValue} ** (size * size),
                .HEAP => allocator.?.alloc(StorageImplType, size * size) catch |err| {
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
                .k = K,
                .n = N,
            };
        }

        pub fn get(self: *const Self, coordinate: Coordinate) StorageImplType {
            assert(self.size == size);
            assert(coordinate.i < size and coordinate.j < size);

            const field = self.board[coordinate.i * size + coordinate.j];

            return field;
        }

        pub fn set(self: *const Self, coordinate: Coordinate, value: StorageImplType) void {
            assert(self.size == size);
            // std.debug.print("size={}, value={}, i={}, j={}\n", .{ size, value, coordinate.i, coordinate.j });
            assert(coordinate.i < size and coordinate.j < size);

            const index = coordinate.i * size + coordinate.j;

            self.board[index] = value;
        }

        pub fn copy(self: *const Self, other: Self) void {
            std.mem.copyForwards(StorageImplType, self.board, other.board);
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
