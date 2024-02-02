pub const Vec4f = extern union {
    p: extern struct { x: f32, y: f32, z: f32, w: f32 },
    c: extern struct { r: f32, g: f32, b: f32, a: f32 },
    v: @Vector(4, f32),

    // vector, vector
    pub inline fn add(o: *Vec4f, a: Vec4f, b: *Vec4f) void {
        o.*.v = a.*.v + b.*.v;
    }

    pub inline fn sub(o: *Vec4f, a: *Vec4f, b: *Vec4f) void {
        o.*.v = a.*.v - b.*.v;
    }

    pub inline fn mul(o: *Vec4f, a: *Vec4f, b: *Vec4f) void {
        o.*.v = a.*.v * b.*.v;
    }

    pub inline fn div(o: *Vec4f, a: *Vec4f, b: *Vec4f) void {
        o.*.v = a.*.v / b.*.v;
    }

    // vector, scalar
    pub inline fn adds(o: *Vec4f, a: *Vec4f, b: f32) void {
        o.*.v = a.*.v + @Vector(4, f32){b, b, b, b};
    }

    pub inline fn subs(o: *Vec4f, a: *Vec4f, b: f32) void {
        o.*.v = a.*.v - @Vector(4, f32){b, b, b, b};
    }

    pub inline fn muls(o: *Vec4f, a: *Vec4f, b: f32) void {
        o.*.v = a.*.v * @Vector(4, f32){b, b, b, b};
    }

    pub inline fn divs(o: *Vec4f, a: *Vec4f, b: f32) void {
        o.*.v = a.*.v / @Vector(4, f32){b, b, b, b};
    }
};
