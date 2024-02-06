const std = @import("std");

const Color = @This();

r: f32 = 0.0,
g: f32 = 0.0,
b: f32 = 0.0,
a: f32 = 0.0,

pub const WHITE = Color.rgb(1.0, 1.0, 1.0);
pub const BLACK = Color.rgb(0.0, 0.0, 0.0);

pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
    return .{
        .r = r,
        .g = g,
        .b = b,
        .a = a,
    };
}

pub fn rgb(r: f32, g: f32, b: f32) Color {
    return rgba(r, g, b, 1.0);
}
