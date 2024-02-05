const std = @import("std");
const vk = @import("vk.zig");

const Image = @This();

pub const Error = error{
    ImageMemoryTypeNotFound,
    FormatSizeNotFound,
};

fn formatSize(format: vk.ImageFormat) !u32 {
    switch (format) {
        .R8G8B8A8Unorm => return 4,
        else => return error.FormatSizeNotFound,
    }
}

pub const Descriptor = struct {
    format: vk.ImageFormat,
    type: vk.ImageType = .Image2D,
    extent: vk.Extent3D,
    mip_levels: u32 = 1,
    array_layers: u32 = 1,
    samples: u32 = 1,
    tiling: vk.ImageTiling = .Optimal,
    usage: vk.ImageUsages,
    sharing_mode: vk.SharingMode = .Exclusive,
    initial_layout: vk.ImageLayout = .Undefined,
    memory: vk.MemoryProperties = .{},
};

vk: vk.api.VkImage,
memory: vk.api.VkDeviceMemory,

format: vk.ImageFormat,

device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !Image {
    const image_info = vk.api.VkImageCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .format = @intFromEnum(desc.format),
        .imageType = @intFromEnum(desc.type),
        .extent = vk.api.VkExtent3D{
            .width = desc.extent.width,
            .height = desc.extent.height,
            .depth = desc.extent.depth,
        },
        .mipLevels = desc.mip_levels,
        .arrayLayers = desc.array_layers,
        .samples = desc.samples,
        .tiling = @intFromEnum(desc.tiling),
        .usage = @bitCast(desc.usage),
        .sharingMode = @intFromEnum(desc.sharing_mode),
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .initialLayout = @intFromEnum(desc.initial_layout),
    };

    var image: vk.api.VkImage = undefined;
    try vk.check(vk.api.vkCreateImage(device.vk, &image_info, null, &image));
    errdefer vk.api.vkDestroyImage(device.vk, image, null);

    var mem_reqs: vk.api.VkMemoryRequirements = undefined;
    vk.api.vkGetImageMemoryRequirements(device.vk, image, &mem_reqs);

    const type_index = device.queryMemoryType(
        mem_reqs.memoryTypeBits,
        desc.memory,
    ) orelse return error.BufferMemoryTypeNotFound;

    const pixel_size = try formatSize(desc.format);
    const row_size = pixel_size * desc.extent.width;
    const image_size = row_size * desc.extent.height;
    const data_size = image_size * desc.extent.depth * desc.array_layers;

    std.debug.assert(data_size > 0);

    const alloc_info = vk.api.VkMemoryAllocateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = mem_reqs.size,
        .memoryTypeIndex = type_index,
    };

    var memory: vk.api.VkDeviceMemory = undefined;
    try vk.check(vk.api.vkAllocateMemory(device.vk, &alloc_info, null, &memory));
    errdefer vk.api.vkFreeMemory(device.vk, memory, null);

    try vk.check(vk.api.vkBindImageMemory(device.vk, image, memory, 0));

    return Image{
        .vk = image,
        .memory = memory,

        .format = desc.format,

        .device = device.vk,
    };
}

pub fn deinit(self: Image) void {
    vk.api.vkFreeMemory(self.device, self.memory, null);
    vk.api.vkDestroyImage(self.device, self.vk, null);
}

pub fn createView(self: Image, desc: vk.ImageView.Descriptor) !vk.ImageView {
    return vk.ImageView.init(self, desc);
}
