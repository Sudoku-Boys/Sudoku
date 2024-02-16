const std = @import("std");

const Meshes = @import("Meshes.zig");
const Materials = @import("Materials.zig");
const Transform = @import("../Transform.zig");

const Object = @This();

mesh: Meshes.Id,
material: Materials.Id,
transform: Transform,
