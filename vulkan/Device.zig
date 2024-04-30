const std = @import("std");
const vk = @import("vk.zig");

const Device = @This();

const DISCRETE_GPU_SCORE: i32 = 1000;
const NO_PHYSICAL_DEVICE_SCORE: i32 = -10000;

pub const REQUIRED_EXTENSIONS = [_][*c]const u8{
    vk.api.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

pub const Error = error{
    /// No physical device was found
    NoPhysicalDevice,
    /// No queue family was found
    NoQueueFamily,
};

/// Get the supported extensions for a physical device.
fn getSupportedExtensions(
    allocator: std.mem.Allocator,
    device: vk.api.VkPhysicalDevice,
) ![]const vk.api.VkExtensionProperties {
    var count: u32 = 0;
    try vk.check(vk.api.vkEnumerateDeviceExtensionProperties(device, null, &count, null));

    const extensions = try allocator.alloc(vk.api.VkExtensionProperties, count);
    try vk.check(vk.api.vkEnumerateDeviceExtensionProperties(device, null, &count, extensions.ptr));

    return extensions;
}

/// Check if an extension is supported by a physical device.
fn isExtensionSupported(
    extensions: []const vk.api.VkExtensionProperties,
    extension: [*c]const u8,
) !bool {
    const str = std.mem.span(extension);

    for (extensions) |ext| {
        if (std.mem.count(u8, str, &ext.extensionName) == 0) {
            return true;
        }
    }

    return false;
}

/// Check if all required extensions are supported by a physical device.
fn isRequiredExtensionsSupported(
    allocator: std.mem.Allocator,
    device: vk.api.VkPhysicalDevice,
) !bool {
    const supportedExtensions = try getSupportedExtensions(allocator, device);
    defer allocator.free(supportedExtensions);

    for (REQUIRED_EXTENSIONS) |extension| {
        if (!try isExtensionSupported(supportedExtensions, extension)) {
            return false;
        }
    }

    return true;
}

fn isDeviceValid(
    allocator: std.mem.Allocator,
    device: vk.api.VkPhysicalDevice,
    surface: ?vk.Surface,
) !bool {
    if (try QueueFamilies.find(allocator, device, surface) == null) {
        return false;
    }

    if (!try isRequiredExtensionsSupported(allocator, device)) {
        return false;
    }

    if (surface) |_surface| {
        _ = _surface;
    }

    return true;
}

/// Rate a physical device.
fn ratePhysicalDevice(
    allocator: std.mem.Allocator,
    device: vk.api.VkPhysicalDevice,
    surface: ?vk.Surface,
) !?i32 {
    if (!try isDeviceValid(allocator, device, surface)) {
        return null;
    }

    var score: i32 = 0;

    var properties: vk.api.VkPhysicalDeviceProperties = undefined;
    var features: vk.api.VkPhysicalDeviceFeatures = undefined;

    vk.api.vkGetPhysicalDeviceProperties(device, &properties);
    vk.api.vkGetPhysicalDeviceFeatures(device, &features);

    if (properties.deviceType == vk.api.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
        score += DISCRETE_GPU_SCORE;
    }

    return score;
}

fn getPhysicalDevices(
    allocator: std.mem.Allocator,
    instance: vk.api.VkInstance,
) ![]const vk.api.VkPhysicalDevice {
    // get the number of physical devices
    var count: u32 = 0;
    try vk.check(vk.api.vkEnumeratePhysicalDevices(instance, &count, null));

    // allocate an array of physical devices
    const devices = try allocator.alloc(vk.api.VkPhysicalDevice, count);
    try vk.check(vk.api.vkEnumeratePhysicalDevices(instance, &count, devices.ptr));

    return devices;
}

fn findPhysicalDevice(
    instance: vk.Instance,
    surface: ?vk.Surface,
) !?vk.api.VkPhysicalDevice {
    const devices = try getPhysicalDevices(instance.allocator, instance.vk);
    defer instance.allocator.free(devices);

    // if there are no physical devices, return null
    if (devices.len == 0) return null;

    // select the physical device with the highest score
    var best_device: ?vk.api.VkPhysicalDevice = null;
    var best_score: i32 = -80085;

    for (devices[0..]) |device| {
        const score = try ratePhysicalDevice(instance.allocator, device, surface) orelse continue;
        if (score > best_score) {
            best_device = device;
            best_score = score;
        }
    }

    return best_device;
}

pub const QueueFamilies = struct {
    graphics: u32,
    present: u32,

    pub const COUNT = 2;

    fn isPresentSupported(
        device: vk.api.VkPhysicalDevice,
        queue_index: u32,
        surface: ?vk.Surface,
    ) !bool {
        if (surface) |_surface| {
            var presentSupported: vk.api.VkBool32 = vk.api.VK_FALSE;
            const result = vk.api.vkGetPhysicalDeviceSurfaceSupportKHR(
                device,
                queue_index,
                _surface.vk,
                &presentSupported,
            );
            try vk.check(result);

            if (presentSupported == vk.api.VK_TRUE) {
                return true;
            }
        }

        return false;
    }

    fn getQueueFamilies(
        allocator: std.mem.Allocator,
        device: vk.api.VkPhysicalDevice,
    ) ![]vk.api.VkQueueFamilyProperties {
        var count: u32 = 0;
        vk.api.vkGetPhysicalDeviceQueueFamilyProperties(device, &count, null);

        const queue_families = try allocator.alloc(vk.api.VkQueueFamilyProperties, count);
        vk.api.vkGetPhysicalDeviceQueueFamilyProperties(device, &count, queue_families.ptr);

        return queue_families;
    }

    fn find(
        allocator: std.mem.Allocator,
        device: vk.api.VkPhysicalDevice,
        surface: ?vk.Surface,
    ) !?QueueFamilies {
        var graphics: ?u32 = null;
        var present: ?u32 = null;

        const queue_families = try QueueFamilies.getQueueFamilies(allocator, device);
        defer allocator.free(queue_families);

        for (queue_families, 0..) |family, i| {
            const queue_index: u32 = @intCast(i);

            if ((family.queueFlags & vk.api.VK_QUEUE_GRAPHICS_BIT) != 0) {
                graphics = queue_index;
            }

            if (try isPresentSupported(device, queue_index, surface)) {
                present = queue_index;
            }
        }

        return .{
            .graphics = graphics orelse return null,
            .present = present orelse return null,
        };
    }

    /// Get the queue indices as an array.
    pub fn indices(self: QueueFamilies) [COUNT]u32 {
        return .{ self.graphics, self.present };
    }
};

fn createDevice(
    physical: vk.api.VkPhysicalDevice,
    extensions: []const [*c]const u8,
    queues: QueueFamilies,
) !vk.api.VkDevice {
    const queueInfo = vk.api.VkDeviceQueueCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = 0,
        .queueCount = 1,
        .pQueuePriorities = &@as(f32, 1.0),
    };

    var queueInfos = [_]vk.api.VkDeviceQueueCreateInfo{queueInfo} ** QueueFamilies.COUNT;

    queueInfos[0].queueFamilyIndex = queues.graphics;
    queueInfos[1].queueFamilyIndex = queues.present;

    var queue_count: u32 = QueueFamilies.COUNT;

    if (queues.graphics == queues.present) {
        queue_count = 1;
    }

    var features: vk.api.VkPhysicalDeviceFeatures = undefined;
    vk.api.vkGetPhysicalDeviceFeatures(physical, &features);

    const deviceInfo = vk.api.VkDeviceCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = queue_count,
        .pQueueCreateInfos = &queueInfos,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
        .pEnabledFeatures = &features,
    };

    var device: vk.api.VkDevice = undefined;
    try vk.check(vk.api.vkCreateDevice(physical, &deviceInfo, null, &device));

    return device;
}

fn getQueue(
    allocator: std.mem.Allocator,
    device: vk.api.VkDevice,
    family: u32,
) vk.Queue {
    var queue: vk.api.VkQueue = undefined;
    vk.api.vkGetDeviceQueue(device, family, 0, &queue);

    return .{
        .vk = queue,
        .allocator = allocator,
    };
}

pub const Descriptor = struct {
    instance: vk.Instance,
    compatible_surface: ?vk.Surface,
};

vk: vk.api.VkDevice,
physical: vk.api.VkPhysicalDevice,
queues: QueueFamilies,
graphics: vk.Queue,
present: vk.Queue,
allocator: std.mem.Allocator,

pub fn init(desc: Descriptor) !Device {
    const physical = try findPhysicalDevice(
        desc.instance,
        desc.compatible_surface,
    ) orelse return Error.NoPhysicalDevice;

    const queues = try QueueFamilies.find(
        desc.instance.allocator,
        physical,
        desc.compatible_surface,
    ) orelse return Error.NoQueueFamily;

    const device = try createDevice(physical, &REQUIRED_EXTENSIONS, queues);

    const graphics = getQueue(desc.instance.allocator, device, queues.graphics);
    const present = getQueue(desc.instance.allocator, device, queues.present);

    return Device{
        .vk = device,
        .physical = physical,
        .queues = queues,
        .graphics = graphics,
        .present = present,
        .allocator = desc.instance.allocator,
    };
}

pub fn deinit(self: Device) void {
    vk.api.vkDestroyDevice(self.vk, null);
}

pub fn waitIdle(self: Device) !void {
    try vk.check(vk.api.vkDeviceWaitIdle(self.vk));
}

pub fn queryMemoryType(
    self: Device,
    type_bits: u32,
    properties: vk.MemoryProperties,
) ?u32 {
    var mem_props: vk.api.VkPhysicalDeviceMemoryProperties = undefined;
    vk.api.vkGetPhysicalDeviceMemoryProperties(self.physical, &mem_props);

    const flags: u32 = @bitCast(properties);
    const mem_types = mem_props.memoryTypes[0..mem_props.memoryTypeCount];

    for (mem_types, 0..) |mem_type, i| {
        const props = mem_type.propertyFlags;
        const mask = @as(u32, 1) << @intCast(i);

        if (type_bits & mask != 0 and (props & flags) == flags) {
            return @intCast(i);
        }
    }

    return null;
}

pub fn createBindGroupPool(
    self: Device,
    desc: vk.BindGroupPool.Descriptor,
) !vk.BindGroupPool {
    return vk.BindGroupPool.init(self, desc);
}

pub fn createBindGroupLayout(
    self: Device,
    desc: vk.BindGroupLayout.Descriptor,
) !vk.BindGroupLayout {
    return vk.BindGroupLayout.init(self, desc);
}

pub fn createBuffer(
    self: Device,
    desc: vk.Buffer.Descriptor,
) !vk.Buffer {
    return vk.Buffer.init(self, desc);
}

pub fn createCommandPool(
    self: Device,
    kind: vk.CommandPool.Kind,
) !vk.CommandPool {
    return vk.CommandPool.init(self, kind);
}

pub fn createComputePipeline(
    self: Device,
    desc: vk.ComputePipeline.Descriptor,
) !vk.ComputePipeline {
    return vk.ComputePipeline.init(self, desc);
}

pub fn createFence(
    self: Device,
    signalled: bool,
) !vk.Fence {
    return vk.Fence.init(self, signalled);
}

pub fn createGraphicsPipeline(
    self: Device,
    desc: vk.GraphicsPipeline.Descriptor,
) !vk.GraphicsPipeline {
    return vk.GraphicsPipeline.init(self, desc);
}

pub fn createImage(
    self: Device,
    desc: vk.Image.Descriptor,
) !vk.Image {
    return vk.Image.init(self, desc);
}

pub fn createRenderPass(
    self: Device,
    desc: vk.RenderPass.Descriptor,
) !vk.RenderPass {
    return vk.RenderPass.init(self, desc);
}

pub fn createSampler(
    self: Device,
    desc: vk.Sampler.Descriptor,
) !vk.Sampler {
    return vk.Sampler.init(self, desc);
}

pub fn createSemaphore(self: Device) !vk.Semaphore {
    return vk.Semaphore.init(self);
}

pub fn createSwapchain(
    self: Device,
    desc: vk.Swapchain.Descriptor,
) !vk.Swapchain {
    return vk.Swapchain.init(self, desc);
}

pub const BufferResource = struct {
    buffer: vk.Buffer,
    offset: u64 = 0,
    size: u64,
};

pub const ImageResource = struct {
    view: vk.ImageView,
    layout: vk.ImageLayout,
};

pub const SamplerResource = struct {
    sampler: vk.Sampler,
};

pub const CombinedImageResource = struct {
    sampler: vk.Sampler,
    view: vk.ImageView,
    layout: vk.ImageLayout,
};

pub const BindingResource = union(enum) {
    buffer: BufferResource,
    storage_image: ImageResource,
    sampled_image: ImageResource,
    sampler: SamplerResource,
    combined_image: CombinedImageResource,

    fn asVk(self: BindingResource) vk.api.VkDescriptorType {
        switch (self) {
            .buffer => return vk.api.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .storage_image => return vk.api.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .sampled_image => return vk.api.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
            .sampler => return vk.api.VK_DESCRIPTOR_TYPE_SAMPLER,
            .combined_image => return vk.api.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        }
    }
};

pub const BindGroupWrite = struct {
    dst: vk.BindGroup,
    binding: u32,
    array_element: u32 = 0,
    resource: BindingResource,
};

pub const UpdateBindGroupsDescriptor = struct {
    writes: []const BindGroupWrite,

    pub const MAX_WRITES = 64;
};

pub fn updateBindGroups(self: Device, desc: UpdateBindGroupsDescriptor) void {
    std.debug.assert(desc.writes.len <= UpdateBindGroupsDescriptor.MAX_WRITES);

    var writes: [UpdateBindGroupsDescriptor.MAX_WRITES]vk.api.VkWriteDescriptorSet = undefined;

    for (desc.writes, 0..) |write, i| {
        writes[i] = vk.api.VkWriteDescriptorSet{
            .sType = vk.api.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .pNext = null,
            .dstSet = write.dst.vk,
            .dstBinding = write.binding,
            .dstArrayElement = write.array_element,
            .descriptorCount = 1,
            .descriptorType = write.resource.asVk(),
            .pImageInfo = null,
            .pBufferInfo = null,
            .pTexelBufferView = null,
        };

        switch (write.resource) {
            .buffer => |resource| {
                writes[i].pBufferInfo = &vk.api.VkDescriptorBufferInfo{
                    .buffer = resource.buffer.vk,
                    .offset = resource.offset,
                    .range = resource.size,
                };
            },
            .sampled_image, .storage_image => |resource| {
                writes[i].pImageInfo = &vk.api.VkDescriptorImageInfo{
                    .sampler = null,
                    .imageView = resource.view.vk,
                    .imageLayout = @intFromEnum(resource.layout),
                };
            },
            .sampler => |resource| {
                writes[i].pImageInfo = &vk.api.VkDescriptorImageInfo{
                    .sampler = resource.sampler.vk,
                    .imageView = null,
                    .imageLayout = vk.api.VK_IMAGE_LAYOUT_UNDEFINED,
                };
            },
            .combined_image => |resource| {
                writes[i].pImageInfo = &vk.api.VkDescriptorImageInfo{
                    .sampler = resource.sampler.vk,
                    .imageView = resource.view.vk,
                    .imageLayout = @intFromEnum(resource.layout),
                };
            },
        }
    }

    vk.api.vkUpdateDescriptorSets(self.vk, @intCast(desc.writes.len), &writes, 0, null);
}

fn getVkFences(self: Device, fences: []const vk.Fence) ![]vk.api.VkFence {
    const vk_fences = try self.allocator.alloc(vk.api.VkFence, fences.len);
    for (fences, 0..) |fence, i| {
        vk_fences[i] = fence.vk;
    }
    return vk_fences;
}

pub fn waitForFences(
    self: Device,
    desc: struct {
        fences: []const vk.Fence,
        wait_all: bool = true,
        timeout: u64 = std.math.maxInt(u64),
    },
) !void {
    const vk_fences = try getVkFences(self, desc.fences);
    defer self.allocator.free(vk_fences);

    try vk.check(vk.api.vkWaitForFences(
        self.vk,
        @intCast(vk_fences.len),
        vk_fences.ptr,
        vk.vkBool(desc.wait_all),
        desc.timeout,
    ));
}

pub fn resetFences(self: Device, fences: []const vk.Fence) !void {
    const vk_fences = try getVkFences(self, fences);
    defer self.allocator.free(vk_fences);

    try vk.check(vk.api.vkResetFences(self.vk, @intCast(vk_fences.len), vk_fences.ptr));
}
