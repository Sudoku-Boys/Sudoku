const std = @import("std");
const vk = @import("vulkan");

const Mesh = @import("Mesh.zig");

const PreparedMesh = @This();

const VertexBuffer = struct {
    name: []const u8,
    buffer: vk.Buffer,
};

allocator: std.mem.Allocator,
vertex_buffers: []const VertexBuffer,
index_buffer: vk.Buffer,
index_count: u32,

pub fn init(
    device: vk.Device,
    staging_buffer: *vk.StagingBuffer,
    mesh: *Mesh,
    allocator: std.mem.Allocator,
) !PreparedMesh {
    if (!mesh.containsAttribute(Mesh.NORMAL)) {
        try mesh.generateNormals();
    }

    if (!mesh.containsAttribute(Mesh.TANGENT)) {
        try mesh.generateTangents();
    }

    const vertex_buffers = try allocator.alloc(
        VertexBuffer,
        mesh.attributes.items.len,
    );
    errdefer allocator.free(vertex_buffers);

    for (mesh.attributes.items, 0..) |attribute, i| {
        const size = attribute.vertices.data.items.len;
        const buffer = try device.createBuffer(.{
            .size = size,
            .usage = .{ .vertex_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });
        errdefer buffer.deinit();

        try staging_buffer.write(attribute.vertices.data.items);
        try staging_buffer.copyBuffer(.{
            .dst = buffer,
            .size = size,
        });

        vertex_buffers[i] = .{
            .name = attribute.name,
            .buffer = buffer,
        };
    }

    const index_buffer = try device.createBuffer(.{
        .size = mesh.indexBytes().len,
        .usage = .{ .index_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer index_buffer.deinit();

    try staging_buffer.write(mesh.indexBytes());
    try staging_buffer.copyBuffer(.{
        .dst = index_buffer,
        .size = mesh.indexBytes().len,
    });

    return .{
        .allocator = allocator,
        .vertex_buffers = vertex_buffers,
        .index_buffer = index_buffer,
        .index_count = @intCast(mesh.indices.items.len),
    };
}

pub fn deinit(self: PreparedMesh) void {
    for (self.vertex_buffers) |vertex_buffer| {
        vertex_buffer.buffer.deinit();
    }

    self.index_buffer.deinit();

    self.allocator.free(self.vertex_buffers);
}

pub fn getAttribute(self: PreparedMesh, name: []const u8) ?vk.Buffer {
    for (self.vertex_buffers) |vertex_buffer| {
        if (std.mem.eql(u8, name, vertex_buffer.name)) {
            return vertex_buffer.buffer;
        }
    }

    return null;
}
