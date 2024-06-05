const Self = @This();

pub fn init() Self {
    return Self {};
}

pub fn deinit(self: Self) void {
    _ = self;
}

pub fn solve(sudoku: anytype) bool {
    _ = sudoku;
    return false;
}
