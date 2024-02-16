const std = @import("std");
const vk = @import("vk.zig");

const ComputePipeline = @This();

fn createShaderModule(device: vk.api.VkDevice, spv: []const u32) !vk.api.VkShaderModule {
    const shader_info = vk.api.VkShaderModuleCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = spv.len * 4,
        .pCode = spv.ptr,
    };

    var shader_module: vk.api.VkShaderModule = undefined;
    try vk.check(vk.api.vkCreateShaderModule(device, &shader_info, null, &shader_module));

    return shader_module;
}

pub const Descriptor = struct {
    shader: vk.Spirv,
    entry_point: [*c]const u8,
    layout: []const vk.BindGroupLayout = &.{},

    pub const MAX_LAYOUTS = 16;
};

vk: vk.api.VkPipeline,
layout: vk.api.VkPipelineLayout,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !ComputePipeline {
    const module = try createShaderModule(device.vk, desc.shader);
    defer vk.api.vkDestroyShaderModule(device.vk, module, null);

    const stage = vk.api.VkPipelineShaderStageCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = vk.api.VK_SHADER_STAGE_COMPUTE_BIT,
        .module = module,
        .pName = desc.entry_point,
        .pSpecializationInfo = null,
    };

    var set_layouts: [Descriptor.MAX_LAYOUTS]vk.api.VkDescriptorSetLayout = undefined;

    for (desc.layout, 0..) |layout, i| {
        set_layouts[i] = layout.vk;
    }

    const layout_info = vk.api.VkPipelineLayoutCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = @intCast(desc.layout.len),
        .pSetLayouts = &set_layouts,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    var layout: vk.api.VkPipelineLayout = undefined;
    try vk.check(vk.api.vkCreatePipelineLayout(
        device.vk,
        &layout_info,
        null,
        &layout,
    ));
    errdefer vk.api.vkDestroyPipelineLayout(device.vk, layout, null);

    const pipeline_info = vk.api.VkComputePipelineCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = stage,
        .layout = layout,
        .basePipelineHandle = null,
        .basePipelineIndex = 0,
    };

    var pipeline: vk.api.VkPipeline = undefined;
    try vk.check(vk.api.vkCreateComputePipelines(
        device.vk,
        null,
        1,
        &pipeline_info,
        null,
        &pipeline,
    ));
    errdefer vk.api.vkDestroyPipeline(device.vk, pipeline, null);

    return .{
        .vk = pipeline,
        .layout = layout,
        .device = device.vk,
    };
}

pub fn deinit(self: ComputePipeline) void {
    vk.api.vkDestroyPipeline(self.device, self.vk, null);
    vk.api.vkDestroyPipelineLayout(self.device, self.layout, null);
}
