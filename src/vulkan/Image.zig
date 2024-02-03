const std = @import("std");
const vk = @import("vk.zig");

pub const Layout = enum {
    Undefined,
    General,
    ColorAttachmentOptimal,
    DepthStencilAttachmentOptimal,
    DepthStencilReadOnlyOptimal,
    ShaderReadOnlyOptimal,
    TransferSrcOptimal,
    TransferDstOptimal,
    Preinitialized,
    DepthReadOnlyStencilAttachmentOptimal,
    DepthAttachmentStencilReadOnlyOptimal,
    DepthAttachmentOptimal,
    DepthReadOnlyOptimal,
    StencilAttachmentOptimal,
    StencilReadOnlyOptimal,
    ReadOnlyOptimal,
    AttachmentOptimal,
    PresentSrc,
    VideoDecodeDst,
    VideoDecodeSrc,
    VideoDecodeDpb,
    SharedPresent,

    pub fn toVk(self: Layout) vk.api.VkImageLayout {
        return switch (self) {
            .Undefined => vk.api.VK_IMAGE_LAYOUT_UNDEFINED,
            .General => vk.api.VK_IMAGE_LAYOUT_GENERAL,
            .ColorAttachmentOptimal => vk.api.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            .DepthStencilAttachmentOptimal => vk.api.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            .DepthStencilReadOnlyOptimal => vk.api.VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL,
            .ShaderReadOnlyOptimal => vk.api.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            .TransferSrcOptimal => vk.api.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            .TransferDstOptimal => vk.api.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            .Preinitialized => vk.api.VK_IMAGE_LAYOUT_PREINITIALIZED,
            .DepthReadOnlyStencilAttachmentOptimal => vk.api.VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL,
            .DepthAttachmentStencilReadOnlyOptimal => vk.api.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL,
            .DepthAttachmentOptimal => vk.api.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL,
            .DepthReadOnlyOptimal => vk.api.VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL,
            .StencilAttachmentOptimal => vk.api.VK_IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL,
            .StencilReadOnlyOptimal => vk.api.VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL,
            .ReadOnlyOptimal => vk.api.VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL,
            .AttachmentOptimal => vk.api.VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL,
            .PresentSrc => vk.api.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            .VideoDecodeDst => vk.api.VK_IMAGE_LAYOUT_VIDEO_DECODE_DST_KHR,
            .VideoDecodeSrc => vk.api.VK_IMAGE_LAYOUT_VIDEO_DECODE_SRC_KHR,
            .VideoDecodeDpb => vk.api.VK_IMAGE_LAYOUT_VIDEO_DECODE_DPB_KHR,
            .SharedPresent => vk.api.VK_IMAGE_LAYOUT_SHARED_PRESENT_KHR,
        };
    }
};

vk: vk.api.VkImage,
device: vk.api.VkDevice,
