const std = @import("std");
const vk = @import("vk.zig");

const GraphicsPipeline = @This();

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

pub const VertexAttribute = struct {
    location: u32,
    format: vk.VertexFormat,
    offset: u32,
};

pub const VertexBinding = struct {
    binding: u32,
    stride: u32,
    input_rate: vk.VertexInputRate = .Vertex,
    attributes: []const VertexAttribute = &.{},
};

pub const VertexStage = struct {
    shader: vk.Spirv,
    entry_point: [*c]const u8 = "main",
    bindings: []const VertexBinding = &.{},
};

pub const FragmentStage = struct {
    shader: vk.Spirv,
    entry_point: [*c]const u8 = "main",
};

pub const InputAssembly = struct {
    topology: vk.PrimitiveTopology = .TriangleList,
    primitive_restart_enable: bool = false,

    fn toVk(self: InputAssembly) vk.api.VkPipelineInputAssemblyStateCreateInfo {
        return vk.api.VkPipelineInputAssemblyStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .topology = @intFromEnum(self.topology),
            .primitiveRestartEnable = vk.vkBool(self.primitive_restart_enable),
        };
    }
};

pub const DepthBias = struct {
    constant_factor: f32 = 0.0,
    clamp: f32 = 0.0,
    slope_factor: f32 = 0.0,
};

pub const Rasterization = struct {
    depth_clamp_enable: bool = false,
    rasterizer_discard_enable: bool = false,
    polygon_mode: vk.PolygonMode = .Fill,
    cull_mode: vk.CullModes = .{ .back = true },
    front_face: vk.FrontFace = .Clockwise,
    depth_bias: ?DepthBias = null,
    line_width: f32 = 1.0,

    fn toVk(self: Rasterization) vk.api.VkPipelineRasterizationStateCreateInfo {
        var info = vk.api.VkPipelineRasterizationStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .depthClampEnable = vk.vkBool(self.depth_clamp_enable),
            .rasterizerDiscardEnable = vk.vkBool(self.rasterizer_discard_enable),
            .polygonMode = @intFromEnum(self.polygon_mode),
            .cullMode = @bitCast(self.cull_mode),
            .frontFace = @intFromEnum(self.front_face),
            .depthBiasEnable = vk.api.VK_FALSE,
            .depthBiasConstantFactor = 0.0,
            .depthBiasClamp = 0.0,
            .depthBiasSlopeFactor = 0.0,
            .lineWidth = 1.0,
        };

        if (self.depth_bias) |bias| {
            info.depthBiasEnable = vk.api.VK_TRUE;
            info.depthBiasConstantFactor = bias.constant_factor;
            info.depthBiasClamp = bias.clamp;
            info.depthBiasSlopeFactor = bias.slope_factor;
        }

        return info;
    }
};

pub const Multisample = struct {
    sample_shading_enable: bool = false,
    rasterization_samples: u32 = 1,
    min_sample_shading: f32 = 1.0,
    alpha_to_coverage_enable: bool = false,
    alpha_to_one_enable: bool = false,

    fn toVk(self: Multisample) vk.api.VkPipelineMultisampleStateCreateInfo {
        return vk.api.VkPipelineMultisampleStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .sampleShadingEnable = vk.vkBool(self.sample_shading_enable),
            .rasterizationSamples = self.rasterization_samples,
            .minSampleShading = self.min_sample_shading,
            .pSampleMask = null,
            .alphaToCoverageEnable = vk.vkBool(self.alpha_to_coverage_enable),
            .alphaToOneEnable = vk.vkBool(self.alpha_to_one_enable),
        };
    }
};

pub const StencilOpState = struct {
    fail_op: vk.StencilOp = .Keep,
    pass_op: vk.StencilOp = .Keep,
    depth_fail_op: vk.StencilOp = .Keep,
    compare_op: vk.CompareOp = .Never,
    compare_mask: u32 = 0,
    write_mask: u32 = 0,
    reference: u32 = 0,

    fn toVk(self: StencilOpState) vk.api.VkStencilOpState {
        return vk.api.VkStencilOpState{
            .failOp = @intFromEnum(self.fail_op),
            .passOp = @intFromEnum(self.pass_op),
            .depthFailOp = @intFromEnum(self.depth_fail_op),
            .compareOp = @intFromEnum(self.compare_op),
            .compareMask = self.compare_mask,
            .writeMask = self.write_mask,
            .reference = self.reference,
        };
    }
};

pub const DepthStencil = struct {
    depth_test: bool = false,
    depth_write: bool = false,
    depth_compare_op: vk.CompareOp = .Less,
    depth_bounds_test: bool = false,
    stencil_test: bool = false,
    front: StencilOpState = .{},
    back: StencilOpState = .{},
    min_depth_bounds: f32 = 0.0,
    max_depth_bounds: f32 = 1.0,

    fn toVk(self: DepthStencil) vk.api.VkPipelineDepthStencilStateCreateInfo {
        return vk.api.VkPipelineDepthStencilStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .depthTestEnable = vk.vkBool(self.depth_test),
            .depthWriteEnable = vk.vkBool(self.depth_write),
            .depthCompareOp = @intFromEnum(self.depth_compare_op),
            .depthBoundsTestEnable = vk.vkBool(self.depth_bounds_test),
            .stencilTestEnable = vk.vkBool(self.stencil_test),
            .front = self.front.toVk(),
            .back = self.back.toVk(),
            .minDepthBounds = self.min_depth_bounds,
            .maxDepthBounds = self.max_depth_bounds,
        };
    }
};

pub const ColorBlendAttachment = struct {
    blend: bool = false,
    src_color_blend_factor: vk.BlendFactor = .One,
    dst_color_blend_factor: vk.BlendFactor = .Zero,
    color_blend_op: vk.BlendOp = .Add,
    src_alpha_blend_factor: vk.BlendFactor = .One,
    dst_alpha_blend_factor: vk.BlendFactor = .Zero,
    alpha_blend_op: vk.BlendOp = .Add,
    color_writes: vk.ColorComponents = .{ .r = true, .g = true, .b = true, .a = true },

    fn toVk(self: ColorBlendAttachment) vk.api.VkPipelineColorBlendAttachmentState {
        return vk.api.VkPipelineColorBlendAttachmentState{
            .blendEnable = vk.vkBool(self.blend),
            .srcColorBlendFactor = @intFromEnum(self.src_color_blend_factor),
            .dstColorBlendFactor = @intFromEnum(self.dst_color_blend_factor),
            .colorBlendOp = @intFromEnum(self.color_blend_op),
            .srcAlphaBlendFactor = @intFromEnum(self.src_alpha_blend_factor),
            .dstAlphaBlendFactor = @intFromEnum(self.dst_alpha_blend_factor),
            .alphaBlendOp = @intFromEnum(self.alpha_blend_op),
            .colorWriteMask = @bitCast(self.color_writes),
        };
    }
};

pub const ColorBlend = struct {
    logic_op: ?vk.LogicOp = null,
    attachments: []const ColorBlendAttachment = &.{},
    blend_constants: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },

    /// Converts the `ColorBlend` to a `VkPipelineColorBlendStateCreateInfo`.
    ///
    /// Note that the `attachments` array is allocated using the provided allocator and must be freed
    /// after the `VkPipelineColorBlendStateCreateInfo` is no longer needed.
    fn toVk(self: ColorBlend, allocator: std.mem.Allocator) !vk.api.VkPipelineColorBlendStateCreateInfo {
        var attachments: [*c]vk.api.VkPipelineColorBlendAttachmentState = null;

        if (self.attachments.len > 0) {
            const alloc = try allocator.alloc(vk.api.VkPipelineColorBlendAttachmentState, self.attachments.len);
            attachments = alloc.ptr;
        }

        for (self.attachments, 0..) |attachment, i| {
            attachments[i] = attachment.toVk();
        }

        var info = vk.api.VkPipelineColorBlendStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .logicOpEnable = vk.api.VK_FALSE,
            .logicOp = vk.api.VK_LOGIC_OP_NO_OP,
            .attachmentCount = @intCast(self.attachments.len),
            .pAttachments = attachments,
            .blendConstants = self.blend_constants,
        };

        if (self.logic_op) |op| {
            info.logicOpEnable = vk.api.VK_TRUE;
            info.logicOp = @intFromEnum(op);
        }

        return info;
    }
};

pub const Descriptor = struct {
    vertex: VertexStage,
    fragment: FragmentStage,
    input_assembly: InputAssembly = .{},
    rasterization: Rasterization = .{},
    multisample: Multisample = .{},
    depth_stencil: ?DepthStencil = .{},
    color_blend: ColorBlend = .{},
    layouts: []const ?vk.BindGroupLayout = &.{},
    render_pass: vk.RenderPass,
    subpass: u32,
};

fn createVertexStage(
    module: vk.api.VkShaderModule,
    descriptor: VertexStage,
) vk.api.VkPipelineShaderStageCreateInfo {
    return vk.api.VkPipelineShaderStageCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = vk.api.VK_SHADER_STAGE_VERTEX_BIT,
        .module = module,
        .pName = descriptor.entry_point,
        .pSpecializationInfo = null,
    };
}

fn createFragmentStage(
    module: vk.api.VkShaderModule,
    descriptor: FragmentStage,
) vk.api.VkPipelineShaderStageCreateInfo {
    return vk.api.VkPipelineShaderStageCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = vk.api.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = module,
        .pName = descriptor.entry_point,
        .pSpecializationInfo = null,
    };
}

vk: vk.api.VkPipeline,
layout: vk.api.VkPipelineLayout,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !GraphicsPipeline {
    const vertex_module = try createShaderModule(device.vk, desc.vertex.shader);
    defer vk.api.vkDestroyShaderModule(device.vk, vertex_module, null);
    var fragment_module = try createShaderModule(device.vk, desc.fragment.shader);
    defer vk.api.vkDestroyShaderModule(device.vk, fragment_module, null);

    var pipelines: [2]vk.api.VkPipelineShaderStageCreateInfo = undefined;
    pipelines[0] = createVertexStage(vertex_module, desc.vertex);
    pipelines[1] = createFragmentStage(fragment_module, desc.fragment);

    const dynamic_states: []const vk.api.VkDynamicState = &.{
        vk.api.VK_DYNAMIC_STATE_VIEWPORT,
        vk.api.VK_DYNAMIC_STATE_SCISSOR,
    };

    const dynamic_state = vk.api.VkPipelineDynamicStateCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .dynamicStateCount = dynamic_states.len,
        .pDynamicStates = dynamic_states.ptr,
    };

    var attribute_count: usize = 0;

    for (desc.vertex.bindings) |binding| {
        attribute_count += binding.attributes.len;
    }

    const vertex_input_bindings = try device.allocator.alloc(vk.api.VkVertexInputBindingDescription, desc.vertex.bindings.len);
    defer device.allocator.free(vertex_input_bindings);
    const vertex_input_attributes = try device.allocator.alloc(vk.api.VkVertexInputAttributeDescription, attribute_count);
    defer device.allocator.free(vertex_input_attributes);

    var attribute_index: u32 = 0;

    for (desc.vertex.bindings, 0..) |binding, i| {
        vertex_input_bindings[i] = .{
            .binding = binding.binding,
            .stride = binding.stride,
            .inputRate = @intFromEnum(binding.input_rate),
        };

        for (binding.attributes) |attribute| {
            vertex_input_attributes[attribute_index] = .{
                .location = attribute.location,
                .binding = binding.binding,
                .format = @intFromEnum(attribute.format),
                .offset = attribute.offset,
            };

            attribute_index += 1;
        }
    }

    const vertex_input = vk.api.VkPipelineVertexInputStateCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .vertexBindingDescriptionCount = @intCast(vertex_input_bindings.len),
        .pVertexBindingDescriptions = vertex_input_bindings.ptr,
        .vertexAttributeDescriptionCount = @intCast(vertex_input_attributes.len),
        .pVertexAttributeDescriptions = vertex_input_attributes.ptr,
    };

    const viewport_state = vk.api.VkPipelineViewportStateCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .viewportCount = 1,
        .pViewports = null,
        .scissorCount = 1,
        .pScissors = null,
    };

    const input_assembly = desc.input_assembly.toVk();
    const rasterizer = desc.rasterization.toVk();
    const multisample = desc.multisample.toVk();

    var depth_stencil: ?vk.api.VkPipelineDepthStencilStateCreateInfo = null;
    if (desc.depth_stencil) |ds| {
        depth_stencil = ds.toVk();
    }

    // color attachment states are allocated, we need to free them later
    const color_blend = try desc.color_blend.toVk(device.allocator);
    defer if (color_blend.pAttachments) |alloc| {
        device.allocator.free(alloc[0..color_blend.attachmentCount]);
    };

    const bind_groups = try device.allocator.alloc(vk.api.VkDescriptorSetLayout, desc.layouts.len);
    defer device.allocator.free(bind_groups);

    // TODO :: proper fix
    const null_layout = try vk.BindGroupLayout.empty(device);

    for (desc.layouts, 0..) |optional_group, i| {
        if (optional_group) |group| {
            bind_groups[i] = group.vk;
        } else {
            bind_groups[i] = null_layout.vk;
        }
    }

    const pipeline_layout = vk.api.VkPipelineLayoutCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = @intCast(bind_groups.len),
        .pSetLayouts = bind_groups.ptr,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    var layout: vk.api.VkPipelineLayout = undefined;
    try vk.check(vk.api.vkCreatePipelineLayout(device.vk, &pipeline_layout, null, &layout));
    errdefer vk.api.vkDestroyPipelineLayout(device.vk, layout, null);

    const graphics_pipeline_info = vk.api.VkGraphicsPipelineCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stageCount = pipelines.len,
        .pStages = &pipelines,
        .pVertexInputState = &vertex_input,
        .pInputAssemblyState = &input_assembly,
        .pTessellationState = null,
        .pViewportState = &viewport_state,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisample,
        .pDepthStencilState = &depth_stencil.?,
        .pColorBlendState = &color_blend,
        .pDynamicState = &dynamic_state,
        .layout = layout,
        .renderPass = desc.render_pass.vk,
        .subpass = desc.subpass,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    var pipeline: vk.api.VkPipeline = undefined;
    try vk.check(vk.api.vkCreateGraphicsPipelines(device.vk, null, 1, &graphics_pipeline_info, null, &pipeline));

    return .{
        .vk = pipeline,
        .layout = layout,
        .device = device.vk,
    };
}

pub fn deinit(self: GraphicsPipeline) void {
    vk.api.vkDestroyPipelineLayout(self.device, self.layout, null);
    vk.api.vkDestroyPipeline(self.device, self.vk, null);
}
