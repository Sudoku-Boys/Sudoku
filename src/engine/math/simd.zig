pub inline fn unpacklo(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
    return @shuffle(f32, v0, v1, @Vector(4, i32){ 0, -1, 1, -2 });
}

pub inline fn unpackhi(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
    return @shuffle(f32, v0, v1, @Vector(4, i32){ 2, -3, 3, -4 });
}

pub inline fn movelh(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
    return @shuffle(f32, v0, v1, @Vector(4, i32){ 0, 1, -1, -2 });
}

pub inline fn movehl(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
    return @shuffle(f32, v0, v1, @Vector(4, i32){ -3, -4, 2, 3 });
}

pub inline fn permute(v0: @Vector(4, f32), comptime mask: @Vector(4, i32)) @Vector(4, f32) {
    return @shuffle(f32, v0, undefined, mask);
}
