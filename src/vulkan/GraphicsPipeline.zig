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

pub const VertexStage = struct {
    shader: vk.Spv,
    entry_point: [*c]const u8 = "main",
};

pub const FragmentStage = struct {
    shader: vk.Spv,
    entry_point: [*c]const u8 = "main",
};

pub const Topology = enum {
    TriangleList,
    TriangleStrip,
    LineList,
    LineStrip,
    PointList,

    fn toVk(self: Topology) vk.api.VkPrimitiveTopology {
        return switch (self) {
            .TriangleList => vk.api.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .TriangleStrip => vk.api.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP,
            .LineList => vk.api.VK_PRIMITIVE_TOPOLOGY_LINE_LIST,
            .LineStrip => vk.api.VK_PRIMITIVE_TOPOLOGY_LINE_STRIP,
            .PointList => vk.api.VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
        };
    }
};

pub const InputAssembly = struct {
    topology: Topology = .TriangleList,
    primitive_restart_enable: bool = false,

    fn toVk(self: InputAssembly) vk.api.VkPipelineInputAssemblyStateCreateInfo {
        return vk.api.VkPipelineInputAssemblyStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .topology = self.topology.toVk(),
            .primitiveRestartEnable = vk.vkBool(self.primitive_restart_enable),
        };
    }
};

pub const PolygonMode = enum {
    Fill,
    Line,
    Point,

    fn toVk(self: PolygonMode) vk.api.VkPolygonMode {
        return switch (self) {
            .Fill => vk.api.VK_POLYGON_MODE_FILL,
            .Line => vk.api.VK_POLYGON_MODE_LINE,
            .Point => vk.api.VK_POLYGON_MODE_POINT,
        };
    }
};

pub const CullMode = enum {
    None,
    Front,
    Back,
    Always,

    fn toVk(self: CullMode) vk.api.VkCullModeFlagBits {
        return switch (self) {
            .None => vk.api.VK_CULL_MODE_NONE,
            .Front => vk.api.VK_CULL_MODE_FRONT_BIT,
            .Back => vk.api.VK_CULL_MODE_BACK_BIT,
            .Always => vk.api.VK_CULL_MODE_FRONT_AND_BACK,
        };
    }
};

pub const FrontFace = enum {
    Clockwise,
    CounterClockwise,

    fn toVk(self: FrontFace) vk.api.VkFrontFace {
        return switch (self) {
            .Clockwise => vk.api.VK_FRONT_FACE_CLOCKWISE,
            .CounterClockwise => vk.api.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        };
    }
};

pub const DepthBias = struct {
    constant_factor: f32 = 0.0,
    clamp: f32 = 0.0,
    slope_factor: f32 = 0.0,
};

pub const Rasterizer = struct {
    depth_clamp_enable: bool = false,
    rasterizer_discard_enable: bool = false,
    polygon_mode: PolygonMode = .Fill,
    cull_mode: CullMode = .None,
    front_face: FrontFace = .Clockwise,
    depth_bias: ?DepthBias = null,
    line_width: f32 = 1.0,

    fn toVk(self: Rasterizer) vk.api.VkPipelineRasterizationStateCreateInfo {
        var info = vk.api.VkPipelineRasterizationStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .depthClampEnable = vk.vkBool(self.depth_clamp_enable),
            .rasterizerDiscardEnable = vk.vkBool(self.rasterizer_discard_enable),
            .polygonMode = self.polygon_mode.toVk(),
            .cullMode = self.cull_mode.toVk(),
            .frontFace = self.front_face.toVk(),
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

pub const CompareOp = enum {
    Never,
    Less,
    Equal,
    LessOrEqual,
    Greater,
    NotEqual,
    GreaterOrEqual,
    Always,

    fn toVk(self: CompareOp) vk.api.VkCompareOp {
        return switch (self) {
            .Never => vk.api.VK_COMPARE_OP_NEVER,
            .Less => vk.api.VK_COMPARE_OP_LESS,
            .Equal => vk.api.VK_COMPARE_OP_EQUAL,
            .LessOrEqual => vk.api.VK_COMPARE_OP_LESS_OR_EQUAL,
            .Greater => vk.api.VK_COMPARE_OP_GREATER,
            .NotEqual => vk.api.VK_COMPARE_OP_NOT_EQUAL,
            .GreaterOrEqual => vk.api.VK_COMPARE_OP_GREATER_OR_EQUAL,
            .Always => vk.api.VK_COMPARE_OP_ALWAYS,
        };
    }
};

pub const StencilOp = enum {
    Keep,
    Zero,
    Replace,
    IncrementAndClamp,
    DecrementAndClamp,
    Invert,
    IncrementAndWrap,
    DecrementAndWrap,

    fn toVk(self: StencilOp) vk.api.VkStencilOp {
        return switch (self) {
            .Keep => vk.api.VK_STENCIL_OP_KEEP,
            .Zero => vk.api.VK_STENCIL_OP_ZERO,
            .Replace => vk.api.VK_STENCIL_OP_REPLACE,
            .IncrementAndClamp => vk.api.VK_STENCIL_OP_INCREMENT_AND_CLAMP,
            .DecrementAndClamp => vk.api.VK_STENCIL_OP_DECREMENT_AND_CLAMP,
            .Invert => vk.api.VK_STENCIL_OP_INVERT,
            .IncrementAndWrap => vk.api.VK_STENCIL_OP_INCREMENT_AND_WRAP,
            .DecrementAndWrap => vk.api.VK_STENCIL_OP_DECREMENT_AND_WRAP,
        };
    }
};

pub const StencilOpState = struct {
    fail_op: StencilOp = .Keep,
    pass_op: StencilOp = .Keep,
    depth_fail_op: StencilOp = .Keep,
    compare_op: CompareOp = .Never,
    compare_mask: u32 = 0,
    write_mask: u32 = 0,
    reference: u32 = 0,

    fn toVk(self: StencilOpState) vk.api.VkStencilOpState {
        return vk.api.VkStencilOpState{
            .failOp = self.fail_op.toVk(),
            .passOp = self.pass_op.toVk(),
            .depthFailOp = self.depth_fail_op.toVk(),
            .compareOp = self.compare_op.toVk(),
            .compareMask = self.compare_mask,
            .writeMask = self.write_mask,
            .reference = self.reference,
        };
    }
};

pub const DepthStencil = struct {
    depth_test_enable: bool = false,
    depth_write_enable: bool = false,
    depth_compare_op: CompareOp = .Less,
    depth_bounds_test_enable: bool = false,
    stencil_test_enable: bool = false,
    front: StencilOpState = .{},
    back: StencilOpState = .{},
    min_depth_bounds: f32 = 0.0,
    max_depth_bounds: f32 = 1.0,

    fn toVk(self: DepthStencil) vk.api.VkPipelineDepthStencilStateCreateInfo {
        return vk.api.VkPipelineDepthStencilStateCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .depthTestEnable = vk.vkBool(self.depth_test_enable),
            .depthWriteEnable = vk.vkBool(self.depth_write_enable),
            .depthCompareOp = self.depth_compare_op.toVk(),
            .depthBoundsTestEnable = vk.vkBool(self.depth_bounds_test_enable),
            .stencilTestEnable = vk.vkBool(self.stencil_test_enable),
            .front = self.front.toVk(),
            .back = self.back.toVk(),
            .minDepthBounds = self.min_depth_bounds,
            .maxDepthBounds = self.max_depth_bounds,
        };
    }
};

pub const BlendFactor = enum {
    Zero,
    One,
    SrcColor,
    OneMinusSrcColor,
    DstColor,
    OneMinusDstColor,
    SrcAlpha,
    OneMinusSrcAlpha,
    DstAlpha,
    OneMinusDstAlpha,
    ConstantColor,
    OneMinusConstantColor,
    ConstantAlpha,
    OneMinusConstantAlpha,
    SrcAlphaSaturate,
    Src1Color,
    OneMinusSrc1Color,
    Src1Alpha,
    OneMinusSrc1Alpha,

    fn toVk(self: BlendFactor) vk.api.VkBlendFactor {
        return switch (self) {
            .Zero => vk.api.VK_BLEND_FACTOR_ZERO,
            .One => vk.api.VK_BLEND_FACTOR_ONE,
            .SrcColor => vk.api.VK_BLEND_FACTOR_SRC_COLOR,
            .OneMinusSrcColor => vk.api.VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR,
            .DstColor => vk.api.VK_BLEND_FACTOR_DST_COLOR,
            .OneMinusDstColor => vk.api.VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR,
            .SrcAlpha => vk.api.VK_BLEND_FACTOR_SRC_ALPHA,
            .OneMinusSrcAlpha => vk.api.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            .DstAlpha => vk.api.VK_BLEND_FACTOR_DST_ALPHA,
            .OneMinusDstAlpha => vk.api.VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA,
            .ConstantColor => vk.api.VK_BLEND_FACTOR_CONSTANT_COLOR,
            .OneMinusConstantColor => vk.api.VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR,
            .ConstantAlpha => vk.api.VK_BLEND_FACTOR_CONSTANT_ALPHA,
            .OneMinusConstantAlpha => vk.api.VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA,
            .SrcAlphaSaturate => vk.api.VK_BLEND_FACTOR_SRC_ALPHA_SATURATE,
            .Src1Color => vk.api.VK_BLEND_FACTOR_SRC1_COLOR,
            .OneMinusSrc1Color => vk.api.VK_BLEND_FACTOR_ONE_MINUS_SRC1_COLOR,
            .Src1Alpha => vk.api.VK_BLEND_FACTOR_SRC1_ALPHA,
            .OneMinusSrc1Alpha => vk.api.VK_BLEND_FACTOR_ONE_MINUS_SRC1_ALPHA,
        };
    }
};

pub const BlendOp = enum {
    Add,
    Subtract,
    ReverseSubtract,
    Min,
    Max,

    fn toVk(self: BlendOp) vk.api.VkBlendOp {
        return switch (self) {
            .Add => vk.api.VK_BLEND_OP_ADD,
            .Subtract => vk.api.VK_BLEND_OP_SUBTRACT,
            .ReverseSubtract => vk.api.VK_BLEND_OP_REVERSE_SUBTRACT,
            .Min => vk.api.VK_BLEND_OP_MIN,
            .Max => vk.api.VK_BLEND_OP_MAX,
        };
    }
};

pub const ColorComponent = packed struct {
    r: bool = false,
    g: bool = false,
    b: bool = false,
    a: bool = false,

    _unused: i28 = 0,

    pub const ALL: ColorComponent = .{ .r = true, .g = true, .b = true, .a = true };

    comptime {
        std.debug.assert(@sizeOf(ColorComponent) == @sizeOf(vk.api.VkColorComponentFlags));
    }

    fn toVk(self: ColorComponent) vk.api.VkColorComponentFlags {
        return @bitCast(self);
    }
};

pub const ColorBlendAttachment = struct {
    blend_enable: bool = false,
    src_color_blend_factor: BlendFactor = .One,
    dst_color_blend_factor: BlendFactor = .Zero,
    color_blend_op: BlendOp = .Add,
    src_alpha_blend_factor: BlendFactor = .One,
    dst_alpha_blend_factor: BlendFactor = .Zero,
    alpha_blend_op: BlendOp = .Add,
    color_write_mask: ColorComponent = ColorComponent.ALL,

    fn toVk(self: ColorBlendAttachment) vk.api.VkPipelineColorBlendAttachmentState {
        return vk.api.VkPipelineColorBlendAttachmentState{
            .blendEnable = vk.vkBool(self.blend_enable),
            .srcColorBlendFactor = self.src_color_blend_factor.toVk(),
            .dstColorBlendFactor = self.dst_color_blend_factor.toVk(),
            .colorBlendOp = self.color_blend_op.toVk(),
            .srcAlphaBlendFactor = self.src_alpha_blend_factor.toVk(),
            .dstAlphaBlendFactor = self.dst_alpha_blend_factor.toVk(),
            .alphaBlendOp = self.alpha_blend_op.toVk(),
            .colorWriteMask = self.color_write_mask.toVk(),
        };
    }
};

pub const LogicOp = enum {
    Clear,
    And,
    AndReverse,
    Copy,
    AndInverted,
    NoOp,
    Xor,
    Or,
    Nor,
    Equivalent,
    Invert,
    OrReverse,
    CopyInverted,
    OrInverted,
    Nand,
    Set,

    fn toVk(self: LogicOp) vk.api.VkLogicOp {
        return switch (self) {
            .Clear => vk.api.VK_LOGIC_OP_CLEAR,
            .And => vk.api.VK_LOGIC_OP_AND,
            .AndReverse => vk.api.VK_LOGIC_OP_AND_REVERSE,
            .Copy => vk.api.VK_LOGIC_OP_COPY,
            .AndInverted => vk.api.VK_LOGIC_OP_AND_INVERTED,
            .NoOp => vk.api.VK_LOGIC_OP_NO_OP,
            .Xor => vk.api.VK_LOGIC_OP_XOR,
            .Or => vk.api.VK_LOGIC_OP_OR,
            .Nor => vk.api.VK_LOGIC_OP_NOR,
            .Equivalent => vk.api.VK_LOGIC_OP_EQUIVALENT,
            .Invert => vk.api.VK_LOGIC_OP_INVERT,
            .OrReverse => vk.api.VK_LOGIC_OP_OR_REVERSE,
            .CopyInverted => vk.api.VK_LOGIC_OP_COPY_INVERTED,
            .OrInverted => vk.api.VK_LOGIC_OP_OR_INVERTED,
            .Nand => vk.api.VK_LOGIC_OP_NAND,
            .Set => vk.api.VK_LOGIC_OP_SET,
        };
    }
};

pub const ColorBlend = struct {
    logic_op: ?LogicOp = null,
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
            info.logicOp = op.toVk();
        }

        return info;
    }
};

pub const Descriptor = struct {
    vertex: VertexStage,
    fragment: FragmentStage,
    input_assembly: InputAssembly = .{},
    rasterizer: Rasterizer = .{},
    multisample: Multisample = .{},
    depth_stencil: ?DepthStencil = .{},
    color_blend: ColorBlend = .{},
    render_pass: vk.RenderPass,
    subpass: u32 = 0,
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

    const vertex_input = vk.api.VkPipelineVertexInputStateCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
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
    const rasterizer = desc.rasterizer.toVk();
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

    const pipeline_layout = vk.api.VkPipelineLayoutCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = 0,
        .pSetLayouts = null,
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
