const std = @import("std");
const vk = @import("vk.zig");

const Semaphore = @This();

vk: vk.api.VkSemaphore,
device: vk.api.VkDevice,

pub fn init(device: vk.Device) !Semaphore {
    const semaphoreInfo = vk.api.VkSemaphoreCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    var semaphore: vk.api.VkSemaphore = undefined;
    try vk.check(vk.api.vkCreateSemaphore(device.vk, &semaphoreInfo, null, &semaphore));

    return .{
        .vk = semaphore,
        .device = device.vk,
    };
}

pub fn deinit(self: Semaphore) void {
    vk.api.vkDestroySemaphore(self.device, self.vk, null);
}
