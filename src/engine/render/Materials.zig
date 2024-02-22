const std = @import("std");

const asset = @import("../asset.zig");

const Materials = @This();

allocator: std.mem.Allocator,
assets: std.AutoHashMapUnmanaged(std.builtin.TypeId, asset.DynamicAssets),

pub fn init(allocator: std.mem.Allocator) Materials {
    return .{
        .allocator = allocator,
        .assets = .{},
    };
}

pub fn deinit(self: *Materials) void {
    var it = self.assets.valueIterator();
    while (it.next()) |assets| {
        assets.destroy(self.allocator);
    }

    self.assets.deinit(self.allocator);
}

pub fn register(self: *Materials, comptime T: type) !void {
    const type_id = std.meta.activeTag(@typeInfo(T));

    if (!self.assets.contains(type_id)) {
        const assets = asset.Assets(T).init(self.allocator);
        const dynamic = try asset.DynamicAssets.alloc(self.allocator, assets);
        try self.assets.put(self.allocator, type_id, dynamic);
    }
}

pub fn add(self: *Materials, material: anytype) !asset.AssetId(@TypeOf(material)) {
    const T = @TypeOf(material);
    try self.register(T);

    return self.getAssets(T).?.add(material);
}

pub fn getAssets(self: *Materials, comptime T: type) ?*asset.Assets(T) {
    const type_id = std.meta.activeTag(@typeInfo(T));

    if (self.assets.get(type_id)) |dynamic| {
        return dynamic.cast(T);
    }

    return null;
}

pub fn getPtr(self: *Materials, asset_id: anytype) ?*@TypeOf(asset_id).Item {
    const T = @TypeOf(asset_id);

    if (self.getAssets(T.Item)) |assets| {
        return assets.getPtr(asset_id);
    }

    return null;
}

pub fn getOpaque(
    self: *Materials,
    asset_id: asset.DynamicAssetId,
) ?*asset.DynamicAssets.Asset {
    if (self.assets.get(asset_id.type_id)) |dynamic| {
        return dynamic.getAsset(asset_id);
    }

    return null;
}
