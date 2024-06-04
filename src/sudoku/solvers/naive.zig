pub fn solve(sudoku: anytype) bool {
    return naive_solve(sudoku, 0, 0);
}

// This gets stuck on a lot of solutions, taken from here https://www.geeksforgeeks.org/sudoku-backtracking-7/.
// TODO generalize sudoku struct more.
fn naive_solve(sudoku: anytype, row: usize, col: usize) bool {
    if (row == sudoku.size and col == 0) {
        return true;
    }
    if (col == sudoku.size) {
        return naive_solve(sudoku, row + 1, 0);
    }

    const current_coordinate = .{ .i = row, .j = col };

    if (sudoku.get(current_coordinate) > 0) {
        return naive_solve(sudoku, row, col + 1);
    }

    for (1..(sudoku.size + 1)) |i| {
        const v = @as(@TypeOf(sudoku.*).Storage.ValueType, @intCast(i));

        if (sudoku.is_valid_then_set(current_coordinate, v)) {
            if (naive_solve(sudoku, row, col + 1)) {
                return true;
            }
        }

        sudoku.set(current_coordinate, 0);
    }

    return false;
}
