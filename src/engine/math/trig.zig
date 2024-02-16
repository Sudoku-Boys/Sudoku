const std = @import("std");

pub const SinCos = struct {
    sin: f32,
    cos: f32,
};

pub inline fn fsincos(f: f32) SinCos {
    const _cos = cos(f);
    var _sin = @sqrt(1.0 - _cos * _cos);
    if (@mod(f, 1.0) >= 0.5) _sin = -_sin;

    return .{
        .sin = _sin,
        .cos = _cos,
    };
}

pub inline fn cos(f: f32) f32 {
    // get abs cos(-x) = cos(x)
    // divide by 2PI, cos(1/2) = 0
    // add 1/2
    // modulus by 1
    // subtract 1/2
    // get abs
    // range in [0, 1/2], equivilant to [0, PI]

    const s0: f32 = @fabs(f) + 0.5;
    const s1: f32 = s0 - @trunc(s0) - 0.5;
    const x: f32 = @fabs(s1);

    const x2: f32 = x * x;
    return x2 * (x2 * (-64.0 * x + 80.0) - 20.0) + 1.0;
}

test "cos error" {
    var max_aerror: f32 = 0;
    var aerror_idx: f32 = 0;
    var max_perror: f32 = 0;
    var perror_idx: f32 = 0;

    for (0..65536) |i| {
        const f: f32 = @as(f32, @floatFromInt(i)) / (2 * 65536.0);
        const tc = cos(f);
        const sc = std.math.cos(f * std.math.pi * 2);

        if (@fabs(tc - sc) > max_aerror) {
            max_aerror = @fabs(tc - sc);
            aerror_idx = f;
        }
        if (@fabs(sc) > 0.000001 and @fabs((tc - sc) / sc) > max_perror) {
            max_perror = @fabs((tc - sc) / sc);
            perror_idx = f;
        }
    }

    std.debug.print("\nmax absolute error cos({d}) e={d}\n\tcos = {d}\n\t std.cos = {d}\n", .{
        aerror_idx,
        max_aerror,
        cos(aerror_idx),
        std.math.cos(aerror_idx * 2 * std.math.pi),
    });
    std.debug.print("max percent error cos({d}) e={d}%\n\tcos = {d}\n\t std.cos = {d}\n", .{
        perror_idx,
        max_perror * 100.0,
        cos(perror_idx),
        std.math.cos(perror_idx * 2 * std.math.pi),
    });
}

test "idiot rule" {
    var max_error: f32 = 0;
    var error_idx: f32 = 0;

    for (0..65536) |i| {
        const f: f32 = @as(f32, @floatFromInt(i)) / (65536.0);
        const tc = cos(f);
        const ts = sin(f);

        if (@fabs(tc * tc + ts * ts - 1) > max_error) {
            max_error = @fabs(tc * tc + ts * ts - 1);
            error_idx = f;
        }
    }

    std.debug.print("\nmax absolute error ({d}) e={d}\n\tcos**2 + sin**2 = {d}\n", .{
        error_idx,
        max_error,
        cos(error_idx) * cos(error_idx) + sin(error_idx) * sin(error_idx),
    });
}

pub inline fn sin(f: f32) f32 {
    const s0: f32 = @fabs(f - 0.25) + 0.5;
    const s1: f32 = s0 - @trunc(s0) - 0.5;
    const x: f32 = @fabs(s1);

    const x2: f32 = x * x;
    return x2 * (x2 * (-64.0 * x + 80.0) - 20.0) + 1.0;
}

// untested danger zone, builds, works?
const v4_0c25: @Vector(4, f32) = .{ 0.25, 0.25, 0.25, 0.25 };
const v4_0c5: @Vector(4, f32) = .{ 0.5, 0.5, 0.5, 0.5 };
const v4_1c0: @Vector(4, f32) = .{ 1.0, 1.0, 1.0, 1.0 };
const v4_20c0: @Vector(4, f32) = .{ 20.0, 20.0, 20.0, 20.0 };
const v4_m64c0: @Vector(4, f32) = .{ -64.0, -64.0, -64.0, -64.0 };
const v4_80c0: @Vector(4, f32) = .{ 80.0, 80.0, 80.0, 80.0 };

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
        const s0: @Vector(8, f32) = @fabs(f[i .. i + 7].*) + v8_0c5;
        const s1: @Vector(8, f32) = s0 - @trunc(s0) - v8_0c5;
        const x: @Vector(8, f32) = @fabs(s1);

        const x2: @Vector(8, f32) = x * x;
        out[i .. i + 7].* = x2 * (x2 * (v8_m64c0 * x + v8_80c0) - v8_20c0) + v8_1c0;
    }
    while (i + 3 < f.len) : (i += 4) {
        const s0: @Vector(4, f32) = @fabs(f[i .. i + 3].*) + v4_0c5;
        const s1: @Vector(4, f32) = s0 - @trunc(s0) - v4_0c5;
        const x: @Vector(4, f32) = @fabs(s1);

        const x2: @Vector(4, f32) = x * x;
        out[i .. i + 3].* = x2 * (x2 * (v4_m64c0 * x + v4_80c0) - v4_20c0) + v4_1c0;
    }
    while (i < f.len) : (i += 1) {
        const s0: f32 = @fabs(f[i]) + 0.5;
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
        const s0: @Vector(8, f32) = @fabs(f[i .. i + 7].* - v8_0c25) + v8_0c5;
        const s1: @Vector(8, f32) = s0 - @trunc(s0) - v8_0c5;
        const x: @Vector(8, f32) = @fabs(s1);

        const x2: @Vector(8, f32) = x * x;
        out[i .. i + 7].* = x2 * (x2 * (v8_m64c0 * x + v8_80c0) - v8_20c0) + v8_1c0;
    }
    while (i + 3 < f.len) : (i += 4) {
        const s0: @Vector(4, f32) = @fabs(f[i .. i + 3].* - v4_0c25) + v4_0c5;
        const s1: @Vector(4, f32) = s0 - @trunc(s0) - v4_0c5;
        const x: @Vector(4, f32) = @fabs(s1);

        const x2: @Vector(4, f32) = x * x;
        out[i .. i + 3].* = x2 * (x2 * (v4_m64c0 * x + v4_80c0) - v4_20c0) + v4_1c0;
    }
    while (i < f.len) : (i += 1) {
        const s0: f32 = @fabs(f[i] - 0.25) + 0.5;
        const s1: f32 = s0 - @trunc(s0) - 0.5;
        const x: f32 = @fabs(s1);

        const x2: f32 = x * x;
        out[i] = x2 * (x2 * (-64.0 * x + 80.0) - 20.0) + 1.0;
    }

    return out;
}
