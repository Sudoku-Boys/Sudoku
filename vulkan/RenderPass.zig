const std = @import("std");
const vk = @import("vk.zig");

const RenderPass = @This();

pub const Attachment = struct {
    format: vk.ImageFormat = vk.ImageFormat.Undefined,
    samples: u32 = 1,
    load_op: vk.LoadOp = .DontCare,
    store_op: vk.StoreOp = .DontCare,
    stencil_load_op: vk.LoadOp = .DontCare,
    stencil_store_op: vk.StoreOp = .DontCare,
    initial_layout: vk.ImageLayout = .Undefined,
    final_layout: vk.ImageLayout = .Undefined,
};

pub const AttachmentReference = struct {
    attachment: u32 = 0,
    layout: vk.ImageLayout = .Undefined,

    fn toVk(self: AttachmentReference) vk.api.VkAttachmentReference {
        return vk.api.VkAttachmentReference{
            .attachment = self.attachment,
            .layout = @intFromEnum(self.layout),
        };
    }
};

pub const Subpass = struct {
    input_attachments: []const AttachmentReference = &.{},
    color_attachments: []const AttachmentReference = &.{},
    resolve_attachments: []const AttachmentReference = &.{},
    depth_stencil_attachment: ?AttachmentReference = null,
    preserve_attachments: []const u32 = &.{},
};

pub const SubpassDependency = struct {
    src_subpass: u32 = vk.SUBPASS_EXTERNAL,
    dst_subpass: u32 = vk.SUBPASS_EXTERNAL,
    src_stage_mask: vk.PipelineStages = .{},
    dst_stage_mask: vk.PipelineStages = .{},
    src_access_mask: vk.Access = .{},
    dst_access_mask: vk.Access = .{},
};

pub const Descriptor = struct {
    attachments: []const Attachment = &.{},
    subpasses: []const Subpass = &.{},
    dependencies: []const SubpassDependency = &.{},

    pub const MAX_ATTACHMENTS: usize = 32;
    pub const MAX_INPUT_ATTACHMENTS: usize = 64;
    pub const MAX_COLOR_ATTACHMENTS: usize = 64;
    pub const MAX_RESOLVE_ATTACHMENTS: usize = 64;
    pub const MAX_SUBPASSES: usize = 64;
    pub const MAX_DEPENDENCIES: usize = 128;
};

vk: vk.api.VkRenderPass,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !RenderPass {
    std.debug.assert(desc.attachments.len <= Descriptor.MAX_ATTACHMENTS);
    std.debug.assert(desc.subpasses.len <= Descriptor.MAX_SUBPASSES);
    std.debug.assert(desc.dependencies.len <= Descriptor.MAX_DEPENDENCIES);

    var vk_attachments: [Descriptor.MAX_ATTACHMENTS]vk.api.VkAttachmentDescription = undefined;

    var vk_subpasses: [Descriptor.MAX_SUBPASSES]vk.api.VkSubpassDescription = undefined;
    var vk_input_attachments: [Descriptor.MAX_INPUT_ATTACHMENTS]vk.api.VkAttachmentReference = undefined;
    var vk_color_attachments: [Descriptor.MAX_COLOR_ATTACHMENTS]vk.api.VkAttachmentReference = undefined;
    var vk_resolve_attachments: [Descriptor.MAX_RESOLVE_ATTACHMENTS]vk.api.VkAttachmentReference = undefined;
    var vk_depth_stencils: [Descriptor.MAX_SUBPASSES]vk.api.VkAttachmentReference = undefined;

    var vk_dependencies: [Descriptor.MAX_DEPENDENCIES]vk.api.VkSubpassDependency = undefined;

    var ic: usize = 0;
    var cc: usize = 0;
    var rc: usize = 0;

    for (desc.attachments, 0..) |attachment, i| {
        vk_attachments[i] = vk.api.VkAttachmentDescription{
            .flags = 0,
            .format = @intFromEnum(attachment.format),
            .samples = attachment.samples,
            .loadOp = @intFromEnum(attachment.load_op),
            .storeOp = @intFromEnum(attachment.store_op),
            .stencilLoadOp = @intFromEnum(attachment.stencil_load_op),
            .stencilStoreOp = @intFromEnum(attachment.stencil_store_op),
            .initialLayout = @intFromEnum(attachment.initial_layout),
            .finalLayout = @intFromEnum(attachment.final_layout),
        };
    }

    for (desc.subpasses, 0..) |subpass, i| {
        const is = ic;
        const cs = cc;
        const rs = rc;

        for (subpass.input_attachments) |input_attachment| {
            vk_input_attachments[ic] = input_attachment.toVk();
            std.debug.assert(ic < Descriptor.MAX_INPUT_ATTACHMENTS);
            ic += 1;
        }

        for (subpass.color_attachments) |color_attachment| {
            vk_color_attachments[cc] = color_attachment.toVk();
            std.debug.assert(cc < Descriptor.MAX_COLOR_ATTACHMENTS);
            cc += 1;
        }

        for (subpass.resolve_attachments) |resolve_attachment| {
            vk_resolve_attachments[rc] = resolve_attachment.toVk();
            std.debug.assert(rc < Descriptor.MAX_RESOLVE_ATTACHMENTS);
            rc += 1;
        }

        vk_subpasses[i] = vk.api.VkSubpassDescription{
            .flags = 0,
            .pipelineBindPoint = vk.api.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .inputAttachmentCount = @intCast(subpass.input_attachments.len),
            .pInputAttachments = &vk_input_attachments[is],
            .colorAttachmentCount = @intCast(subpass.color_attachments.len),
            .pColorAttachments = &vk_color_attachments[cs],
            .pResolveAttachments = null,
            .pDepthStencilAttachment = null,
            .preserveAttachmentCount = @intCast(subpass.preserve_attachments.len),
            .pPreserveAttachments = subpass.preserve_attachments.ptr,
        };

        if (subpass.depth_stencil_attachment) |depth_stencil_attachment| {
            vk_depth_stencils[i] = depth_stencil_attachment.toVk();
            vk_subpasses[i].pDepthStencilAttachment = &vk_depth_stencils[i];
        }

        if (subpass.resolve_attachments.len > 0) {
            std.debug.assert(subpass.resolve_attachments.len == subpass.color_attachments.len);
            vk_subpasses[i].pResolveAttachments = &vk_resolve_attachments[rs];
        }
    }

    for (desc.dependencies, 0..) |dependency, i| {
        vk_dependencies[i] = vk.api.VkSubpassDependency{
            .srcSubpass = dependency.src_subpass,
            .dstSubpass = dependency.dst_subpass,
            .srcStageMask = @bitCast(dependency.src_stage_mask),
            .dstStageMask = @bitCast(dependency.dst_stage_mask),
            .srcAccessMask = @bitCast(dependency.src_access_mask),
            .dstAccessMask = @bitCast(dependency.dst_access_mask),
            .dependencyFlags = 0,
        };
    }

    const render_pass_info = vk.api.VkRenderPassCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .attachmentCount = @intCast(desc.attachments.len),
        .pAttachments = &vk_attachments,
        .subpassCount = @intCast(desc.subpasses.len),
        .pSubpasses = &vk_subpasses,
        .dependencyCount = @intCast(desc.dependencies.len),
        .pDependencies = &vk_dependencies,
    };

    var render_pass: vk.api.VkRenderPass = undefined;
    try vk.check(vk.api.vkCreateRenderPass(device.vk, &render_pass_info, null, &render_pass));

    return RenderPass{
        .vk = render_pass,
        .device = device.vk,
    };
}

pub fn deinit(self: RenderPass) void {
    vk.api.vkDestroyRenderPass(self.device, self.vk, null);
}
