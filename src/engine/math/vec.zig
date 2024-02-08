const std = @import("std");

pub fn vec2(v0: f32, v1: f32) Vec2 {
    return Vec2.init(v0, v1);
}

pub fn vec3(v0: f32, v1: f32, v2: f32) Vec3 {
    return Vec3.init(v0, v1, v2);
}

pub fn vec4(v0: f32, v1: f32, v2: f32, v3: f32) Vec4 {
    return Vec4.init(v0, v1, v2, v3);
}

pub const Vec2 = extern union {
    _: extern struct { x: f32, y: f32 },
    f: [2]f32,
    v: @Vector(2, f32),

    pub usingnamespace VecBase(@This(), 2);

    pub const ZERO = vec2(0, 0);

    pub fn init(v0: f32, v1: f32) Vec2 {
        return Vec2{ .v = .{ v0, v1 } };
    }

    pub fn all(v: anytype) Vec2 {
        if (@TypeOf(v) == Vec2) return v;
        if (@TypeOf(v) == f32 or @TypeOf(v) == comptime_float) {
            return Vec2{ .v = .{ v, v } };
        }

        @compileError("Invalid type for all");
    }

    pub fn reflect(vec: Vec2, normal: Vec2) Vec2 {
        return Vec3{ .v = vec.sub(normal.muls(2 * vec.dot(normal))) };
    }
};

pub const Vec3 = extern union {
    _: extern struct { x: f32, y: f32, z: f32 },
    f: [3]f32,
    v: @Vector(3, f32),

    pub usingnamespace VecBase(@This(), 3);

    pub const ZERO = vec3(0, 0, 0);
    pub const ONE = vec3(1, 1, 1);
    pub const X = vec3(1, 0, 0);
    pub const Y = vec3(0, 1, 0);
    pub const Z = vec3(0, 0, 1);
    pub const NEG_X = vec3(-1, 0, 0);
    pub const NEG_Y = vec3(0, -1, 0);
    pub const NEG_Z = vec3(0, 0, -1);

    pub fn init(v0: f32, v1: f32, v2: f32) Vec3 {
        return Vec3{ .v = .{ v0, v1, v2 } };
    }

    pub fn all(v: anytype) Vec3 {
        if (@TypeOf(v) == Vec3) return v;
        if (@TypeOf(v) == f32 or @TypeOf(v) == comptime_float) {
            return Vec3{ .v = .{ v, v, v } };
        }

        @compileError("Invalid type for all");
    }

    pub fn reflect(vec: Vec3, normal: Vec3) Vec3 {
        return Vec3{ .v = vec.sub(normal.muls(2 * vec.dot(normal))) };
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3{ .v = .{
            a._.y * b._.z - a._.z * b._.y,
            a._.z * b._.x - a._.x * b._.z,
            a._.x * b._.y - a._.y * b._.x,
        } };
    }
};

pub const Vec4 = extern union {
    _: extern struct { x: f32, y: f32, z: f32, w: f32 },
    f: [4]f32,
    v: @Vector(4, f32),

    pub usingnamespace VecBase(@This(), 4);

    pub fn init(v0: f32, v1: f32, v2: f32, v3: f32) Vec4 {
        return Vec4{ .v = .{ v0, v1, v2, v3 } };
    }

    pub fn all(v: anytype) Vec4 {
        if (@TypeOf(v) == Vec4) return v;
        if (@TypeOf(v) == f32 or @TypeOf(v) == comptime_float) {
            return Vec4{ .v = .{ v, v, v, v } };
        }

        @compileError("Invalid type for all");
    }
};

fn swizzleType(comptime size: usize) type {
    return switch (size) {
        1 => f32,
        2 => Vec2,
        3 => Vec3,
        4 => Vec4,
        else => @compileError("Invalid swizzle size"),
    };
}

fn VecBase(comptime T: type, comptime size: usize) type {
    return struct {
        pub fn add(a: T, b: anytype) T {
            if (@TypeOf(b) == T) {
                return .{ .v = a.v + b.v };
            }

            if (@TypeOf(b) == f32 or @TypeOf(b) == comptime_float) {
                return .{ .v = a.v + @as(@Vector(size, f32), @splat(b)) };
            }

            @compileError("Invalid type for add");
        }
        pub fn sub(a: T, b: anytype) T {
            if (@TypeOf(b) == T) {
                return .{ .v = a.v - b.v };
            }

            if (@TypeOf(b) == f32 or @TypeOf(b) == comptime_float) {
                return .{ .v = a.v - @as(@Vector(size, f32), @splat(b)) };
            }

            @compileError("Invalid type for sub");
        }
        pub fn mul(a: T, b: anytype) T {
            if (@TypeOf(b) == T) {
                return .{ .v = a.v * b.v };
            }

            if (@TypeOf(b) == f32 or @TypeOf(b) == comptime_float) {
                return .{ .v = a.v * @as(@Vector(size, f32), @splat(b)) };
            }

            @compileError("Invalid type for mul");
        }
        pub fn div(a: T, b: anytype) T {
            if (@TypeOf(b) == T) {
                return .{ .v = a.v / b.v };
            }

            if (@TypeOf(b) == f32 or @TypeOf(b) == comptime_float) {
                return .{ .v = a.v / @as(@Vector(size, f32), @splat(b)) };
            }

            @compileError("Invalid type for div");
        }

        pub fn addEq(a: *T, b: anytype) void {
            a.* = a.add(b);
        }
        pub fn subEq(a: *T, b: anytype) void {
            a.* = a.sub(b);
        }
        pub fn mulEq(a: *T, b: anytype) void {
            a.* = a.mul(b);
        }
        pub fn divEq(a: *T, b: anytype) void {
            a.* = a.div(b);
        }

        pub fn adds(a: T, b: f32) T {
            return a.add(b);
        }
        pub fn subs(a: T, b: f32) T {
            return a.sub(b);
        }
        pub fn muls(a: T, b: f32) T {
            return a.mul(b);
        }
        pub fn divs(a: T, b: f32) T {
            return a.div(b);
        }

        pub fn neg(a: T) T {
            return .{ .v = -a.v };
        }

        pub fn dot(a: T, b: T) f32 {
            @setFloatMode(.Optimized);
            return @reduce(.Add, a.v * b.v);
        }

        pub fn len(a: T) f32 {
            return @sqrt(dot(a, a));
        }

        pub fn normalize(a: T) T {
            return mul(a, 1 / @sqrt(dot(a, a)));
        }

        pub fn normalize_or_zero(a: T) T {
            const len_squared = dot(a, a);
            return if (len_squared > 0) mul(a, 1 / @sqrt(len_squared)) else a;
        }

        pub fn swizzle(self: T, comptime wiz: []const u8) swizzleType(wiz.len) {
            var ret: swizzleType(wiz.len) = undefined;

            inline for (0..wiz.len) |i| {
                const slice = wiz[i .. i + 1];
                @field(ret, "v")[i] =
                    if (comptime std.mem.eql(u8, slice, "0")) 0 else if (comptime std.mem.eql(u8, slice, "1")) 1 else @field(self, "v")[
                    switch (wiz[i]) {
                        'x', 'r', 's', 'u' => 0,
                        'y', 'g', 't', 'v' => 1,
                        'z', 'b', 'p' => 2,
                        'w', 'a', 'q' => 3,
                        else => @compileError("Idiot...\n\tfix your swizzle"),
                    }
                ];
            }

            return ret;
        }
    };
}
