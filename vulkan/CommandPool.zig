const std = @import("std");
const vk = @import("vk.zig");

const CommandPool = @This();

pub const Kind = enum {
    Graphics,
    Present,
};

vk: vk.api.VkCommandPool,
device: vk.api.VkDevice,
kind: Kind,
allocator: std.mem.Allocator,

pub fn init(device: vk.Device, kind: Kind) !CommandPool {
    const queue = switch (kind) {
        .Graphics => device.queues.graphics,
        .Present => device.queues.present,
    };

    const poolInfo = vk.api.VkCommandPoolCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = null,
        .flags = vk.api.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = queue,
    };

    var pool: vk.api.VkCommandPool = undefined;
    try vk.check(vk.api.vkCreateCommandPool(device.vk, &poolInfo, null, &pool));

    return CommandPool{
        .vk = pool,
        .device = device.vk,
        .kind = kind,
        .allocator = device.allocator,
    };
}

pub fn deinit(self: CommandPool) void {
    vk.api.vkDestroyCommandPool(self.device, self.vk, null);
}

pub fn alloc(self: CommandPool, level: vk.CommandBuffer.Level) !vk.CommandBuffer {
    return try vk.CommandBuffer.init(self, level);
}
