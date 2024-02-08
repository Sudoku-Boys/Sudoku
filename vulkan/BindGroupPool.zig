const std = @import("std");
const vk = @import("vk.zig");

const BindGroupPool = @This();

pub const PoolSize = struct {
    type: vk.BindingType,
    count: u32,
};

pub const Descriptor = struct {
    pool_sizes: []const PoolSize,
    max_groups: u32,

    pub const MAX_POOL_SIZES = 16;
};

vk: vk.api.VkDescriptorPool,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !BindGroupPool {
    var pool_sizes: [Descriptor.MAX_POOL_SIZES]vk.api.VkDescriptorPoolSize = undefined;

    for (desc.pool_sizes, 0..) |pool_size, i| {
        pool_sizes[i] = vk.api.VkDescriptorPoolSize{
            .type = @intFromEnum(pool_size.type),
            .descriptorCount = pool_size.count,
        };
    }

    const pool_info = vk.api.VkDescriptorPoolCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .maxSets = desc.max_groups,
        .poolSizeCount = @intCast(desc.pool_sizes.len),
        .pPoolSizes = &pool_sizes,
    };

    var pool: vk.api.VkDescriptorPool = undefined;
    try vk.check(vk.api.vkCreateDescriptorPool(device.vk, &pool_info, null, &pool));

    return BindGroupPool{
        .vk = pool,
        .device = device.vk,
    };
}

pub fn deinit(self: BindGroupPool) void {
    vk.api.vkDestroyDescriptorPool(self.device, self.vk, null);
}

pub fn alloc(self: BindGroupPool, layout: vk.BindGroupLayout) !vk.BindGroup {
    const alloc_info = vk.api.VkDescriptorSetAllocateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .pNext = null,
        .descriptorPool = self.vk,
        .descriptorSetCount = 1,
        .pSetLayouts = &layout.vk,
    };

    var descriptor_set: vk.api.VkDescriptorSet = undefined;
    try vk.check(vk.api.vkAllocateDescriptorSets(self.device, &alloc_info, &descriptor_set));

    return .{
        .vk = descriptor_set,
    };
}
