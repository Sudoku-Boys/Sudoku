const std = @import("std");
const vk = @import("vk.zig");

const BindGroupLayout = @This();

pub const Entry = struct {
    binding: u32,
    type: vk.BindingType,
    stages: vk.ShaderStages = .{},
    count: u32 = 1,
};

pub const Descriptor = struct {
    entries: []const Entry = &.{},

    pub const MAX_ENTRIES = 32;
};

vk: vk.api.VkDescriptorSetLayout,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !BindGroupLayout {
    var bindings: [Descriptor.MAX_ENTRIES]vk.api.VkDescriptorSetLayoutBinding = undefined;

    for (desc.entries, 0..) |binding, i| {
        bindings[i] = vk.api.VkDescriptorSetLayoutBinding{
            .binding = binding.binding,
            .descriptorType = @intFromEnum(binding.type),
            .descriptorCount = binding.count,
            .stageFlags = @bitCast(binding.stages),
            .pImmutableSamplers = null,
        };
    }

    const layout_info = vk.api.VkDescriptorSetLayoutCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = @intCast(desc.entries.len),
        .pBindings = &bindings,
    };

    var layout: vk.api.VkDescriptorSetLayout = undefined;
    try vk.check(vk.api.vkCreateDescriptorSetLayout(device.vk, &layout_info, null, &layout));

    return .{
        .vk = layout,
        .device = device.vk,
    };
}

/// TODO :: remove me
// TODO :: remove me
pub fn empty(device: vk.Device) !BindGroupLayout {
    const layout_info = vk.api.VkDescriptorSetLayoutCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = 0,
        .pBindings = null,
    };

    var layout: vk.api.VkDescriptorSetLayout = undefined;
    try vk.check(vk.api.vkCreateDescriptorSetLayout(device.vk, &layout_info, null, &layout));

    return .{
        .vk = layout,
        .device = device.vk,
    };
}

pub fn deinit(self: BindGroupLayout) void {
    vk.api.vkDestroyDescriptorSetLayout(self.device, self.vk, null);
}
