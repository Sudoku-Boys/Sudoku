const std = @import("std");
const vk = @import("vk.zig");

const BindGroupLayout = @This();

pub const BindingType = enum {
    Sampler,
    CombinedImageSampler,
    SampledImage,
    StorageImage,
    UniformTexelBuffer,
    StorageTexelBuffer,
    UniformBuffer,
    StorageBuffer,
    UniformBufferDynamic,
    StorageBufferDynamic,
    InputAttachment,

    pub fn asVk(self: BindingType) vk.api.VkDescriptorType {
        return switch (self) {
            .Sampler => vk.api.VK_DESCRIPTOR_TYPE_SAMPLER,
            .CombinedImageSampler => vk.api.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .SampledImage => vk.api.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
            .StorageImage => vk.api.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .UniformTexelBuffer => vk.api.VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER,
            .StorageTexelBuffer => vk.api.VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER,
            .UniformBuffer => vk.api.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .StorageBuffer => vk.api.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .UniformBufferDynamic => vk.api.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC,
            .StorageBufferDynamic => vk.api.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC,
            .InputAttachment => vk.api.VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT,
        };
    }
};

pub const Binding = struct {
    binding: u32,
    type: BindingType,
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
            .descriptorType = binding.type.asVk(),
            .descriptorCount = binding.count,
            .stageFlags = binding.stages.asBits(),
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
