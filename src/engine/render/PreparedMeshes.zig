const std = @import("std");
const vk = @import("vulkan");

const asset = @import("../asset.zig");

const Mesh = @import("Mesh.zig");
const PreparedMesh = @import("PreparedMesh.zig");

const PreparedMeshes = @This();

meshes: std.AutoHashMap(usize, PreparedMesh),

pub fn init(allocator: std.mem.Allocator) PreparedMeshes {
    return .{
        .meshes = std.AutoHashMap(usize, PreparedMesh).init(allocator),
    };
}

pub fn deinit(self: *PreparedMeshes) void {
    var it = self.meshes.valueIterator();
    while (it.next()) |mesh| {
        mesh.deinit();
    }

    self.meshes.deinit();
}

pub fn get(self: PreparedMeshes, id: asset.AssetId(Mesh)) ?PreparedMesh {
    return self.meshes.get(id.index);
}

pub fn system(
    allocator: std.mem.Allocator,
    device: *vk.Device,
    staging_buffer: *vk.StagingBuffer,
    meshes: *asset.Assets(Mesh),
    prepared: *PreparedMeshes,
) !void {
    var it = meshes.iterator();
    while (it.next()) |entry| {
        const index = entry.id.index;

        if (prepared.meshes.contains(index)) continue;

        std.log.debug("Preparing mesh: {}\n", .{index});

        const prepared_mesh = try PreparedMesh.init(
            device.*,
            staging_buffer,
            entry.item(),
            allocator,
        );
        errdefer prepared_mesh.deinit();

        try prepared.meshes.put(index, prepared_mesh);
    }
}
