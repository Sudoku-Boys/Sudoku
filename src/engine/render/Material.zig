const std = @import("std");
const vk = @import("vulkan");

const Material = @This();

type_id: std.builtin.TypeId,
prepare: *const fn () anyerror!void,
draw: *const fn () anyerror!void,
deinit: *const fn () void,
