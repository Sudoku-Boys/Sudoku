const std = @import("std");
const vk = @import("vk.zig");

const Surface = @This();

vk: vk.api.VkSurfaceKHR,
instance: vk.api.VkInstance,

pub fn deinit(self: Surface) void {
    vk.api.vkDestroySurfaceKHR(self.instance, self.vk, null);
}
