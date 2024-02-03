const std = @import("std");
const vk = @import("vk.zig");

const ImageView = @This();

pub const ViewType = enum {
    Image2D,
    Image3D,
    ImageCube,
    ImageArray,

    fn toVk(self: ViewType) vk.api.VkImageViewType {
        return switch (self) {
            .Image2D => vk.api.VK_IMAGE_VIEW_TYPE_2D,
            .Image3D => vk.api.VK_IMAGE_VIEW_TYPE_3D,
            .ImageCube => vk.api.VK_IMAGE_VIEW_TYPE_CUBE,
            .ImageArray => vk.api.VK_IMAGE_VIEW_TYPE_2D_ARRAY,
        };
    }
};

pub const Descriptor = struct {
    view_type: ViewType,
    format: vk.api.VkFormat,
    base_mip_level: u32 = 0,
    mip_levels: u32 = 1,
    base_array_layer: u32 = 0,
    array_layers: u32 = 1,
};

vk: vk.api.VkImageView,
device: vk.api.VkDevice,

pub fn init(image: vk.Image, desc: Descriptor) !ImageView {
    return fromVk(image.device, image.vk, desc);
}

pub fn fromVk(device: vk.api.VkDevice, image: vk.api.VkImage, desc: Descriptor) !ImageView {
    const view_info = vk.api.VkImageViewCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .image = image,
        .viewType = desc.view_type.toVk(),
        .format = desc.format,
        .components = vk.api.VkComponentMapping{
            .r = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = vk.api.VkImageSubresourceRange{
            .aspectMask = vk.api.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = desc.base_mip_level,
            .levelCount = desc.mip_levels,
            .baseArrayLayer = desc.base_array_layer,
            .layerCount = desc.array_layers,
        },
    };

    var view: vk.api.VkImageView = undefined;
    try vk.check(vk.api.vkCreateImageView(device, &view_info, null, &view));

    return .{
        .vk = view,
        .device = device,
    };
}

pub fn deinit(self: ImageView) void {
    vk.api.vkDestroyImageView(self.device, self.vk, null);
}
