const Self = @This();

pub fn init() Self {
    return Self{};
}

pub fn deinit(self: Self) void {
    _ = self;
}

pub fn solve(self: Self, sudoku: anytype) !bool {
    return self.naive_solve(sudoku, 0, 0);
}

// This gets stuck on a lot of solutions, taken from here https://www.geeksforgeeks.org/sudoku-backtracking-7/.
fn naive_solve(self: Self, sudoku: anytype, row: usize, col: usize) bool {
    if (row == sudoku.size and col == 0) {
        return true;
    }
    if (col == sudoku.size) {
        return self.naive_solve(sudoku, row + 1, 0);
    }

    const current_coordinate = .{ .i = row, .j = col };

    if (sudoku.get(current_coordinate) > 0) {
        return self.naive_solve(sudoku, row, col + 1);
    }

    for (1..(sudoku.size + 1)) |i| {
        const v = @as(@TypeOf(sudoku.*).Storage.ValueType, @intCast(i));

        if (sudoku.is_safe_move(current_coordinate, v)) {
            sudoku.set(current_coordinate, v);

            if (self.naive_solve(sudoku, row, col + 1)) {
                return true;
            }
        }

        sudoku.set(current_coordinate, 0);
    }

    return false;
}
