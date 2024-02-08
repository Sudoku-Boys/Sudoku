const std = @import("std");

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

vertices: std.ArrayList(Vertex),
indices: std.ArrayList(u32),

pub fn init(allocator: std.mem.Allocator) Mesh {
    const vertices = std.ArrayList(Vertex).init(allocator);
    const indices = std.ArrayList(u32).init(allocator);

    return .{
        .vertices = vertices,
        .indices = indices,
    };
}

pub fn deinit(self: Mesh) void {
    self.vertices.deinit();
    self.indices.deinit();
}

pub fn vertexBytes(self: Mesh) []const u8 {
    return std.mem.sliceAsBytes(self.vertices.items);
}

pub fn indexBytes(mesh: Mesh) []const u8 {
    return std.mem.sliceAsBytes(mesh.indices.items);
}

pub fn cube(allocator: std.mem.Allocator, size: f32, color: u32) !Mesh {
    const cube_vertices = .{
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

    const cube_indices = .{
        0,  1,  2,  2,  3,  0,
        4,  6,  5,  7,  6,  4,
        8,  9,  10, 10, 11, 8,
        12, 14, 13, 15, 14, 12,
        16, 17, 18, 18, 19, 16,
        20, 22, 21, 23, 22, 20,
    };

    var vertices = std.ArrayList(Vertex).init(allocator);
    try vertices.appendSlice(&cube_vertices);

    var indices = std.ArrayList(u32).init(allocator);
    try indices.appendSlice(&cube_indices);

    return .{
        .vertices = vertices,
        .indices = indices,
    };
}
