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
    depth_stencil_attachment: AttachmentReference = .{},
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
};

vk: vk.api.VkRenderPass,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !RenderPass {
    var vk_attachments = try device.allocator.alloc(vk.api.VkAttachmentDescription, desc.attachments.len);
    defer device.allocator.free(vk_attachments);

    var vk_subpasses = try device.allocator.alloc(vk.api.VkSubpassDescription, desc.subpasses.len);
    defer device.allocator.free(vk_subpasses);

    var vk_dependencies = try device.allocator.alloc(vk.api.VkSubpassDependency, desc.dependencies.len);
    defer device.allocator.free(vk_dependencies);

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
        std.debug.assert(subpass.resolve_attachments.len <= subpass.color_attachments.len);

        var input_attachments = try device.allocator.alloc(vk.api.VkAttachmentReference, subpass.input_attachments.len);
        errdefer device.allocator.free(input_attachments);

        var color_attachments = try device.allocator.alloc(vk.api.VkAttachmentReference, subpass.color_attachments.len);
        errdefer device.allocator.free(color_attachments);

        var resolve_attachments: [*c]vk.api.VkAttachmentReference = null;

        if (subpass.resolve_attachments.len > 0) {
            const alloc = try device.allocator.alloc(vk.api.VkAttachmentReference, subpass.resolve_attachments.len);
            errdefer device.allocator.free(alloc);
            resolve_attachments = alloc.ptr;
        }

        for (subpass.input_attachments, 0..) |input_attachment, j| {
            input_attachments[j] = input_attachment.toVk();
        }

        for (subpass.color_attachments, 0..) |color_attachment, j| {
            color_attachments[j] = color_attachment.toVk();
        }

        for (subpass.resolve_attachments, 0..) |resolve_attachment, j| {
            resolve_attachments[j] = resolve_attachment.toVk();
        }

        vk_subpasses[i] = vk.api.VkSubpassDescription{
            .flags = 0,
            .pipelineBindPoint = vk.api.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .inputAttachmentCount = @intCast(subpass.input_attachments.len),
            .pInputAttachments = input_attachments.ptr,
            .colorAttachmentCount = @intCast(subpass.color_attachments.len),
            .pColorAttachments = color_attachments.ptr,
            .pResolveAttachments = resolve_attachments,
            .pDepthStencilAttachment = null,
            .preserveAttachmentCount = @intCast(subpass.preserve_attachments.len),
            .pPreserveAttachments = subpass.preserve_attachments.ptr,
        };
    }

    defer {
        for (vk_subpasses) |subpass| {
            device.allocator.free(subpass.pInputAttachments[0..subpass.inputAttachmentCount]);
            device.allocator.free(subpass.pColorAttachments[0..subpass.colorAttachmentCount]);

            if (subpass.pResolveAttachments) |resolve_attachments| {
                device.allocator.free(resolve_attachments[0..subpass.colorAttachmentCount]);
            }
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
        .attachmentCount = @intCast(vk_attachments.len),
        .pAttachments = vk_attachments.ptr,
        .subpassCount = @intCast(vk_subpasses.len),
        .pSubpasses = vk_subpasses.ptr,
        .dependencyCount = 0,
        .pDependencies = null,
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
