const std = @import("std");

const Mesh = @import("Mesh.zig");
const Transform = @import("../Transform.zig");
const asset = @import("../asset.zig");

const Object = @This();

mesh: asset.AssetId(Mesh),
material: asset.DynamicAssetId,
transform: Transform,
