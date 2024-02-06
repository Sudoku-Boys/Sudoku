const std = @import("std");
const vk = @import("vulkan");

const Mesh = @This();

pub const Vertex = packed struct {
    position: [3]f32,
    color: [4]f32,
};

vertices: std.ArrayList(Vertex),
indices: std.ArrayList(u32),

pub fn init(allocator: std.mem.Allocator) Mesh {
    return .{
        .vertices = std.ArrayList(Vertex).init(allocator),
        .indices = std.ArrayList(u32).init(allocator),
    };
}

pub fn deinit(mesh: *Mesh) void {
    std.ArrayList(Vertex).deinit(&mesh.vertices);
    std.ArrayList(u32).deinit(&mesh.indices);
}

pub fn vertexBytes(mesh: *Mesh) []u8 {
    return std.ArrayList(Vertex).bytes(&mesh.vertices);
}

pub fn indexBytes(mesh: *Mesh) []u8 {
    return std.ArrayList(u32).bytes(&mesh.indices);
}
