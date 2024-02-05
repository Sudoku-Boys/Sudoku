const std = @import("std");
const vk = @import("vk.zig");

const BindGroupLayout = @This();

pub const Binding = struct {
    binding: u32,
    type: vk.BindingType,
    stages: vk.ShaderStages = .{},
    count: u32 = 1,
};

pub const Descriptor = struct {
    bindings: []const Binding = &.{},
};

vk: vk.api.VkDescriptorSetLayout,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !BindGroupLayout {
    const bindings = try device.allocator.alloc(vk.api.VkDescriptorSetLayoutBinding, desc.bindings.len);

    for (desc.bindings, 0..) |binding, i| {
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
        .bindingCount = @intCast(bindings.len),
        .pBindings = bindings.ptr,
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
