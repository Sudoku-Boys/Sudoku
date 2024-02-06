const std = @import("std");
const vk = @import("vulkan");

const math = @import("../../math.zig");

const Mesh = @This();

pub const Vertex = extern struct {
    position: math.Vec3,
    normal: math.Vec3,
    color: u32,

    pub const ATTRIBUTES = &.{
        .{
            .location = 0,
            .format = .f32x3,
            .offset = @offsetOf(Mesh.Vertex, "position"),
        },
        .{
            .location = 1,
            .format = .f32x3,
            .offset = @offsetOf(Mesh.Vertex, "normal"),
        },
        .{
            .location = 2,
            .format = .u32x1,
            .offset = @offsetOf(Mesh.Vertex, "color"),
        },
    };
};

vertices: []const Vertex,
indices: []const u32,

pub fn cube(comptime size: f32, color: u32) Mesh {
    const vertices = .{
        // front
        .{ .position = math.vec3(-1.0, -1.0, 1.0).muls(size), .normal = math.Vec3.Z, .color = color },
        .{ .position = math.vec3(1.0, -1.0, 1.0).muls(size), .normal = math.Vec3.Z, .color = color },
        .{ .position = math.vec3(1.0, 1.0, 1.0).muls(size), .normal = math.Vec3.Z, .color = color },
        .{ .position = math.vec3(-1.0, 1.0, 1.0).muls(size), .normal = math.Vec3.Z, .color = color },
        // back
        .{ .position = math.vec3(-1.0, -1.0, -1.0).muls(size), .normal = math.Vec3.NEG_Z, .color = color },
        .{ .position = math.vec3(1.0, -1.0, -1.0).muls(size), .normal = math.Vec3.NEG_Z, .color = color },
        .{ .position = math.vec3(1.0, 1.0, -1.0).muls(size), .normal = math.Vec3.NEG_Z, .color = color },
        .{ .position = math.vec3(-1.0, 1.0, -1.0).muls(size), .normal = math.Vec3.NEG_Z, .color = color },
        // top
        .{ .position = math.vec3(-1.0, 1.0, 1.0).muls(size), .normal = math.Vec3.Y, .color = color },
        .{ .position = math.vec3(1.0, 1.0, 1.0).muls(size), .normal = math.Vec3.Y, .color = color },
        .{ .position = math.vec3(1.0, 1.0, -1.0).muls(size), .normal = math.Vec3.Y, .color = color },
        .{ .position = math.vec3(-1.0, 1.0, -1.0).muls(size), .normal = math.Vec3.Y, .color = color },
        // bottom
        .{ .position = math.vec3(-1.0, -1.0, 1.0).muls(size), .normal = math.Vec3.NEG_Y, .color = color },
        .{ .position = math.vec3(1.0, -1.0, 1.0).muls(size), .normal = math.Vec3.NEG_Y, .color = color },
        .{ .position = math.vec3(1.0, -1.0, -1.0).muls(size), .normal = math.Vec3.NEG_Y, .color = color },
        .{ .position = math.vec3(-1.0, -1.0, -1.0).muls(size), .normal = math.Vec3.NEG_Y, .color = color },
        // right
        .{ .position = math.vec3(1.0, -1.0, 1.0).muls(size), .normal = math.Vec3.X, .color = color },
        .{ .position = math.vec3(1.0, -1.0, -1.0).muls(size), .normal = math.Vec3.X, .color = color },
        .{ .position = math.vec3(1.0, 1.0, -1.0).muls(size), .normal = math.Vec3.X, .color = color },
        .{ .position = math.vec3(1.0, 1.0, 1.0).muls(size), .normal = math.Vec3.X, .color = color },
        // left
        .{ .position = math.vec3(-1.0, -1.0, 1.0).muls(size), .normal = math.Vec3.NEG_X, .color = color },
        .{ .position = math.vec3(-1.0, -1.0, -1.0).muls(size), .normal = math.Vec3.NEG_X, .color = color },
        .{ .position = math.vec3(-1.0, 1.0, -1.0).muls(size), .normal = math.Vec3.NEG_X, .color = color },
        .{ .position = math.vec3(-1.0, 1.0, 1.0).muls(size), .normal = math.Vec3.NEG_X, .color = color },
    };

    const indices = .{
        0,  1,  2,  2,  3,  0,
        4,  5,  6,  6,  7,  4,
        8,  9,  10, 10, 11, 8,
        12, 13, 14, 14, 15, 12,
        16, 17, 18, 18, 19, 16,
        20, 21, 22, 22, 23, 20,
    };

    return .{
        .vertices = &vertices,
        .indices = &indices,
    };
}

pub fn vertexBytes(self: Mesh) []const u8 {
    return std.mem.sliceAsBytes(self.vertices);
}

pub fn indexBytes(mesh: Mesh) []const u8 {
    return std.mem.sliceAsBytes(mesh.indices);
}
