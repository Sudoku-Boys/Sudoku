const std = @import("std");
const Self = @This();

i: usize,
j: usize,

/// Get the index of the row this coordinate is part of.
pub inline fn get_row_index(self: Self) usize {
    return self.i;
}

/// Get the index of the column this coordinate is part of.
pub inline fn get_col_index(self: Self) usize {
    return self.j;
}

/// Get the index of the grid this coordinate is part of.
pub inline fn get_grid_index(self: Self, k: usize, n: usize) usize {
    return (self.i / n) * k + (self.j / n);
}

/// The the offset coordinate of the row constraint at the index.
/// So get_row_coord(0) would be the first coordinate in the row.
pub inline fn new_row_coord(index: usize, offset: usize) Self {
    return Self{ .i = index, .j = offset };
}

/// The the offset coordinate of the row constraint at the index.
/// So get_col_coord(0) would be the first coordinate in the column.
pub inline fn new_col_coord(index: usize, offset: usize) Self {
    return Self{ .i = offset, .j = index };
}

/// The the offset coordinate of the grid constraint at the index.
/// So get_grid_coord(index, K, N, 3) would be the first coordinate in the grid.
pub inline fn new_grid_coord(index: usize, k: usize, n: usize, offset: usize) Self {
    const row = (index / k) * n + (offset / n);
    const col = (index % k) * n + (offset % n);
    return Self{ .i = row, .j = col };
}

/// Get the row coordinate at the offset.
pub inline fn get_row_coord(self: Self, offset: usize) Self {
    return Self.new_row_coord(self.get_row_index(), offset);
}

pub inline fn get_first_row_coord(self: Self) Self {
    return Self.new_row_coord(self.get_row_index(), 0);
}

pub inline fn get_last_row_coord(self: Self, size: usize) Self {
    return Self.new_row_coord(self.get_row_index(), size - 1);
}

/// Get the column coordinate at the offset.
pub inline fn get_col_coord(self: Self, offset: usize) Self {
    return Self.new_col_coord(self.get_col_index(), offset);
}

pub inline fn get_first_col_coord(self: Self) Self {
    return Self.new_col_coord(self.get_col_index(), 0);
}

pub inline fn get_last_col_coord(self: Self, size: usize) Self {
    return Self.new_col_coord(self.get_col_index(), size - 1);
}

/// Get the grid coordinate at the offset.
pub inline fn get_grid_coord(self: Self, k: usize, n: usize, offset: usize) Self {
    return Self.new_grid_coord(self.get_grid_index(k, n), k, n, offset);
}

pub inline fn get_first_grid_coord(self: Self, k: usize, n: usize) Self {
    return Self.new_grid_coord(self.get_grid_index(k, n), k, n, 0);
}

pub inline fn get_last_grid_coord(self: Self, k: usize, n: usize) Self {
    return Self.new_grid_coord(self.get_grid_index(k, n), k, n, n * n - 1);
}

pub inline fn equals(self: Self, other: Self) bool {
    return self.i == other.i and self.j == other.j;
}

pub fn random(max: usize, rng: *std.Random) Self {
    const row = rng.intRangeLessThan(usize, 0, max);
    const col = rng.intRangeLessThan(usize, 0, max);
    return Self{ .i = row, .j = col };
}
