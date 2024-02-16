const std = @import("std");
const vk = @import("vk.zig");

const Framebuffer = @This();

vk: vk.api.VkFramebuffer,
device: vk.api.VkDevice,

pub fn deinit(self: Framebuffer) void {
    vk.api.vkDestroyFramebuffer(self.device, self.vk, null);
}
