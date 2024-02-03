const std = @import("std");
const vk = @import("vk.zig");

const Fence = @This();

vk: vk.api.VkFence,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, signalled: bool) !Fence {
    const flags = if (signalled) vk.api.VK_FENCE_CREATE_SIGNALED_BIT else 0;
    const fenceInfo = vk.api.VkFenceCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .pNext = null,
        .flags = @intCast(flags),
    };

    var fence: vk.api.VkFence = undefined;
    try vk.check(vk.api.vkCreateFence(device.vk, &fenceInfo, null, &fence));

    return .{
        .vk = fence,
        .device = device.vk,
    };
}

pub fn deinit(self: Fence) void {
    vk.api.vkDestroyFence(self.device, self.vk, null);
}

pub fn wait(
    self: Fence,
    desc: struct {
        wait_all: bool = true,
        timeout: u64 = std.math.maxInt(u64),
    },
) !void {
    try vk.check(vk.api.vkWaitForFences(
        self.device,
        1,
        &self.vk,
        vk.vkBool(desc.wait_all),
        desc.timeout,
    ));
}

pub fn reset(self: Fence) !void {
    try vk.check(vk.api.vkResetFences(self.device, 1, &self.vk));
}
