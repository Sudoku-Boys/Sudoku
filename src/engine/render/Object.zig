const std = @import("std");

const Meshes = @import("Meshes.zig").Meshes;
const Materials = @import("Materials.zig").Materials;
const Transform = @import("../Transform.zig");

const Object = @This();

mesh: Meshes.Id,
material: Materials.Id,
transform: Transform,
