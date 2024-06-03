const Self = @This();

i: usize,
j: usize,

pub fn equals(self: Self, other: Self) bool {
    return self.i == other.i and self.j == other.j;
}
