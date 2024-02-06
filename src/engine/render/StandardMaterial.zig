const std = @import("std");
const vk = @import("vulkan");
const Color = @import("../Color.zig");

const StandardMaterial = @This();

color: Color = Color.WHITE,
