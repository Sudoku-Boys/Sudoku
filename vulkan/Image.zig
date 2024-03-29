const std = @import("std");
const vk = @import("vk.zig");

const Image = @This();

pub const Error = error{
    ImageMemoryTypeNotFound,
    ImageInvalidFormat,
};

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
extent: vk.Extent3D,
type: vk.ImageType,
mip_levels: u32,
array_layers: u32,
samples: u32,
tiling: vk.ImageTiling,
usage: vk.ImageUsages,
sharing_mode: vk.SharingMode,

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
        .extent = desc.extent,
        .type = desc.type,
        .mip_levels = desc.mip_levels,
        .array_layers = desc.array_layers,
        .samples = desc.samples,
        .tiling = desc.tiling,
        .usage = desc.usage,
        .sharing_mode = desc.sharing_mode,

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
