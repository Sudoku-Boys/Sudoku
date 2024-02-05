const std = @import("std");
const vk = @import("vk.zig");

const BindGroup = @This();

vk: vk.api.VkDescriptorSet,
