const std = @import("std");
const vk = @import("vk.zig");

const Buffer = @This();

pub const Error = error{
    BufferMemoryTypeNotFound,
};

pub const Usage = packed struct {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    uniform_texel_buffer: bool = false,
    storage_texel_buffer: bool = false,
    uniform_buffer: bool = false,
    storage_buffer: bool = false,
    index_buffer: bool = false,
    vertex_buffer: bool = false,
    indirect_buffer: bool = false,

    _unused: u23 = 0,

    comptime {
        std.debug.assert(@sizeOf(Usage) == @sizeOf(u32));
    }

    pub fn asBits(self: Usage) u32 {
        return @bitCast(self);
    }
};

pub const Descriptor = struct {
    size: usize,
    usage: Usage,
    memory: vk.MemoryProperties = .{},
};

fn findMemoryType(
    mem_props: vk.api.VkPhysicalDeviceMemoryProperties,
    type_filter: u32,
    flags: vk.api.VkMemoryPropertyFlags,
) ?u32 {
    for (0..mem_props.memoryTypeCount) |i| {
        const props = mem_props.memoryTypes[i].propertyFlags;
        const mask = @as(u32, 1) << @intCast(i);

        if (type_filter & (mask) != 0 and (props & flags) == flags) {
            return @intCast(i);
        }
    }

    return null;
}

vk: vk.api.VkBuffer,
memory: vk.api.VkDeviceMemory,
device: vk.api.VkDevice,
usage: Usage,
size: usize,

memory_properties: vk.MemoryProperties,
type_index: u32,

pub fn init(device: vk.Device, desc: Descriptor) !Buffer {
    const buffer_info = vk.api.VkBufferCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .size = @intCast(desc.size),
        .usage = desc.usage.asBits(),
        .sharingMode = vk.api.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
    };

    var buffer: vk.api.VkBuffer = undefined;
    try vk.check(vk.api.vkCreateBuffer(device.vk, &buffer_info, null, &buffer));
    errdefer vk.api.vkDestroyBuffer(device.vk, buffer, null);

    var mem_reqs: vk.api.VkMemoryRequirements = undefined;
    vk.api.vkGetBufferMemoryRequirements(device.vk, buffer, &mem_reqs);

    var mem_props: vk.api.VkPhysicalDeviceMemoryProperties = undefined;
    vk.api.vkGetPhysicalDeviceMemoryProperties(device.physical, &mem_props);

    const type_index = findMemoryType(
        mem_props,
        mem_reqs.memoryTypeBits,
        desc.memory.asBits(),
    ) orelse return error.BufferMemoryTypeNotFound;

    const alloc_info = vk.api.VkMemoryAllocateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = buffer_info.size,
        .memoryTypeIndex = type_index,
    };

    var memory: vk.api.VkDeviceMemory = undefined;
    try vk.check(vk.api.vkAllocateMemory(device.vk, &alloc_info, null, &memory));

    try vk.check(vk.api.vkBindBufferMemory(device.vk, buffer, memory, 0));

    return .{
        .vk = buffer,
        .memory = memory,
        .device = device.vk,
        .usage = desc.usage,
        .size = desc.size,

        .memory_properties = desc.memory,
        .type_index = type_index,
    };
}

pub fn deinit(self: Buffer) void {
    vk.api.vkDestroyBuffer(self.device, self.vk, null);
    vk.api.vkFreeMemory(self.device, self.memory, null);
}

pub const MemoryMapFlags = packed struct {
    read: bool = false,
    write: bool = false,
    persistent: bool = false,
    coherent: bool = false,

    _unused: u28 = 0,

    comptime {
        std.debug.assert(@sizeOf(MemoryMapFlags) == @sizeOf(u32));
    }

    pub fn asBits(self: MemoryMapFlags) u32 {
        return @bitCast(self);
    }
};

pub const MapDescriptor = struct {
    offset: u64,
    size: u64,
    /// Apparently this should always be 0.
    flags: MemoryMapFlags = .{},
};

pub fn map(self: Buffer, desc: MapDescriptor) ![]u8 {
    std.debug.assert(desc.offset + desc.size <= self.size);
    std.debug.assert(self.memory_properties.host_visible);

    var data: [*]u8 = undefined;

    try vk.check(vk.api.vkMapMemory(
        self.device,
        self.memory,
        desc.offset,
        desc.size,
        desc.flags.asBits(),
        @ptrCast(&data),
    ));

    return data[0..desc.size];
}

pub fn unmap(self: Buffer) void {
    vk.api.vkUnmapMemory(self.device, self.memory);
}
