const std = @import("std");

const inv2pi = 0.159154943091895335768883763372;

pub inline fn fcos(f: f32) f32 {
    @setRuntimeSafety(false);

    // from float to int
    const source: u32 = @intFromFloat(f * @as(f32, @floatFromInt(0x100000000)) * inv2pi);
    //
    //	abs(0x40000000 - source) = diff
    //	0.5 - diff;
    //
    // shift right to switch to 31 bit fixed point
    var it: i32 = @intCast(source >> 1);
    // do this to make range between [0, 0.5]
    it = 0x40000000 - std.zig.c_builtins.__builtin_abs(0x40000000 - it);

    const x: i64 = it;

    //
    //	1 - 20(x^2) + 80(x^4) - 64(x^5)
    //	1 - 5(2x)^2 + 5(2x)^4 - 2(2x)^5
    //	1 + 5((2x)^4 - (2x)^2) - 2(2x)^5
    //

    const x2: i64 = (x * x) >> 29;
    const x4: i64 = x2 * x2 >> 31;
    const c: i64 = 0x80000000 + 5 * (x4 - x2) - (x4 * x >> 29);

    return @as(f32, @floatFromInt(c)) / @as(f32, @floatFromInt(0x80000000));
}

pub inline fn fsin(f: f32) f32 {
    @setRuntimeSafety(false);

    // from float to int
    const source: u32 = @intFromFloat(f * @as(f32, @floatFromInt(0x100000000)) * inv2pi - 0.25);

    var it: i32 = @intCast(source >> 1);
    it = 0x40000000 - std.zig.c_builtins.__builtin_abs(0x40000000 - it);

    const x: i64 = it;

    const x2: i64 = (x * x) >> 29;
    const x4: i64 = x2 * x2 >> 31;
    const c: i64 = 0x80000000 + 5 * (x4 - x2) - (x4 * x >> 29);

    return @as(f32, @floatFromInt(c)) / @as(f32, @floatFromInt(0x80000000));
}

pub inline fn cos(f: f32) f32 {
    // get abs cos(-x) = cos(x)
    // divide by 2PI, cos(1/2) = 0
    // add 1/2
    // modulus by 1
    // subtract 1/2
    // get abs
    // range in [0, 1/2], equivilant to [0, PI]

    const s0: f32 = @fabs(f * inv2pi) + 0.5;
    const s1: f32 = s0 - @trunc(s0) - 0.5;
    const x: f32 = @fabs(s1);

    const x2: f32 = x * x;
    return x2 * (x2 * (-64.0 * x + 80.0) - 20.0) + 1.0;
}

pub inline fn sin(f: f32) f32 {
    const s0: f32 = @fabs(f * inv2pi - 0.25) + 0.5;
    const s1: f32 = s0 - @trunc(s0) - 0.5;
    const x: f32 = @fabs(s1);

    const x2: f32 = x * x;
    return x2 * (x2 * (-64.0 * x + 80.0) - 20.0) + 1.0;
}

// untested danger zone, builds, works?
const v4_inv2pi: @Vector(4, f32) = .{ inv2pi, inv2pi, inv2pi, inv2pi };
const v4_0c25: @Vector(4, f32) = .{ 0.25, 0.25, 0.25, 0.25 };
const v4_0c5: @Vector(4, f32) = .{ 0.5, 0.5, 0.5, 0.5 };
const v4_1c0: @Vector(4, f32) = .{ 1.0, 1.0, 1.0, 1.0 };
const v4_20c0: @Vector(4, f32) = .{ 20.0, 20.0, 20.0, 20.0 };
const v4_m64c0: @Vector(4, f32) = .{ -64.0, -64.0, -64.0, -64.0 };
const v4_80c0: @Vector(4, f32) = .{ 80.0, 80.0, 80.0, 80.0 };

const v8_inv2pi: @Vector(8, f32) = .{ inv2pi, inv2pi, inv2pi, inv2pi, inv2pi, inv2pi, inv2pi, inv2pi };
const v8_0c25: @Vector(8, f32) = .{ 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25 };
const v8_0c5: @Vector(8, f32) = .{ 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 };
const v8_1c0: @Vector(8, f32) = .{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
const v8_20c0: @Vector(8, f32) = .{ 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0 };
const v8_m64c0: @Vector(8, f32) = .{ -64.0, -64.0, -64.0, -64.0, -64.0, -64.0, -64.0, -64.0 };
const v8_80c0: @Vector(8, f32) = .{ 80.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0 };

pub inline fn cosv(f: []f32) []f32 {
    var i: u32 = 0;

    var out: [f.len]f32 = undefined;

    while (i + 7 < f.len) : (i += 8) {
        const s0: @Vector(8, f32) = @fabs(f[i .. i + 7].* * v8_inv2pi) + v8_0c5;
        const s1: @Vector(8, f32) = s0 - @trunc(s0) - v8_0c5;
        const x: @Vector(8, f32) = @fabs(s1);

        const x2: @Vector(8, f32) = x * x;
        out[i .. i + 7].* = x2 * (x2 * (v8_m64c0 * x + v8_80c0) - v8_20c0) + v8_1c0;
    }
    while (i + 3 < f.len) : (i += 4) {
        const s0: @Vector(4, f32) = @fabs(f[i .. i + 3].* * v4_inv2pi) + v4_0c5;
        const s1: @Vector(4, f32) = s0 - @trunc(s0) - v4_0c5;
        const x: @Vector(4, f32) = @fabs(s1);

        const x2: @Vector(4, f32) = x * x;
        out[i .. i + 3].* = x2 * (x2 * (v4_m64c0 * x + v4_80c0) - v4_20c0) + v4_1c0;
    }
    while (i < f.len) : (i += 1) {
        const s0: f32 = @fabs(f[i] * inv2pi) + 0.5;
        const s1: f32 = s0 - @trunc(s0) - 0.5;
        const x: f32 = @fabs(s1);

        const x2: f32 = x * x;
        out[i] = x2 * (x2 * (-64.0 * x + 80.0) - 20.0) + 1.0;
    }

    return out;
}

pub inline fn sinv(f: []f32) []f32 {
    var i: u32 = 0;

    var out: [f.len]f32 = undefined;

    while (i + 7 < f.len) : (i += 8) {
        const s0: @Vector(8, f32) = @fabs(f[i .. i + 7].* * v8_inv2pi - v8_0c25) + v8_0c5;
        const s1: @Vector(8, f32) = s0 - @trunc(s0) - v8_0c5;
        const x: @Vector(8, f32) = @fabs(s1);

        const x2: @Vector(8, f32) = x * x;
        out[i .. i + 7].* = x2 * (x2 * (v8_m64c0 * x + v8_80c0) - v8_20c0) + v8_1c0;
    }
    while (i + 3 < f.len) : (i += 4) {
        const s0: @Vector(4, f32) = @fabs(f[i .. i + 3].* * v4_inv2pi - v4_0c25) + v4_0c5;
        const s1: @Vector(4, f32) = s0 - @trunc(s0) - v4_0c5;
        const x: @Vector(4, f32) = @fabs(s1);

        const x2: @Vector(4, f32) = x * x;
        out[i .. i + 3].* = x2 * (x2 * (v4_m64c0 * x + v4_80c0) - v4_20c0) + v4_1c0;
    }
    while (i < f.len) : (i += 1) {
        const s0: f32 = @fabs(f[i] * inv2pi - 0.25) + 0.5;
        const s1: f32 = s0 - @trunc(s0) - 0.5;
        const x: f32 = @fabs(s1);

        const x2: f32 = x * x;
        out[i] = x2 * (x2 * (-64.0 * x + 80.0) - 20.0) + 1.0;
    }

    return out;
}
