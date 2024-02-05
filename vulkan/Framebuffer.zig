const std = @import("std");
const vk = @import("vk.zig");

const Framebuffer = @This();

vk: vk.api.VkFramebuffer,
device: vk.api.VkDevice,

pub const Descriptor = struct {
    render_pass: vk.RenderPass,
    attachments: []const vk.ImageView,
    extent: vk.Extent2D,
    layers: u32 = 1,
};

pub fn init(device: vk.Device, desc: Descriptor) !Framebuffer {
    const attachments = try device.allocator.alloc(vk.api.VkImageView, desc.attachments.len);
    defer device.allocator.free(attachments);

    for (desc.attachments, 0..) |attachment, i| {
        attachments[i] = attachment.vk;
    }

    const framebufferInfo = vk.api.VkFramebufferCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .renderPass = desc.render_pass.vk,
        .attachmentCount = @intCast(desc.attachments.len),
        .pAttachments = attachments.ptr,
        .width = desc.extent.width,
        .height = desc.extent.height,
        .layers = desc.layers,
    };

    var framebuffer: vk.api.VkFramebuffer = undefined;
    try vk.check(vk.api.vkCreateFramebuffer(device.vk, &framebufferInfo, null, &framebuffer));

    return .{
        .vk = framebuffer,
        .device = device.vk,
    };
}

pub fn deinit(self: Framebuffer) void {
    vk.api.vkDestroyFramebuffer(self.device, self.vk, null);
}
