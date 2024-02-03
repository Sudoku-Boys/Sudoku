const std = @import("std");
const vk = @import("vk.zig");
const Window = @import("../engine/Window.zig");

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

    var extensions = try allocator.alloc(vk.api.VkExtensionProperties, count);
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
    surface: ?vk.api.VkSurfaceKHR,
) !bool {
    if (try Queues.find(allocator, device, surface) == null) {
        return false;
    }

    if (!try isRequiredExtensionsSupported(allocator, device)) {
        return false;
    }

    if (surface) |_surface| {
        var swapChainSupport = try SwapchainSupport.query(allocator, device, _surface);
        if (!swapChainSupport.isAdequate()) {
            return false;
        }
    }

    return true;
}

/// Rate a physical device.
fn ratePhysicalDevice(
    allocator: std.mem.Allocator,
    device: vk.api.VkPhysicalDevice,
    surface: ?vk.api.VkSurfaceKHR,
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
    var devices = try allocator.alloc(vk.api.VkPhysicalDevice, count);
    try vk.check(vk.api.vkEnumeratePhysicalDevices(instance, &count, devices.ptr));

    return devices;
}

fn findPhysicalDevice(
    allocator: std.mem.Allocator,
    instance: vk.api.VkInstance,
    surface: ?vk.api.VkSurfaceKHR,
) !?vk.api.VkPhysicalDevice {
    const devices = try getPhysicalDevices(allocator, instance);
    defer allocator.free(devices);

    // if there are no physical devices, return null
    if (devices.len == 0) return null;

    // select the physical device with the highest score
    var best_device: ?vk.api.VkPhysicalDevice = null;
    var best_score: i32 = -80085;

    for (devices[0..]) |device| {
        var score = try ratePhysicalDevice(allocator, device, surface) orelse continue;
        if (score > best_score) {
            best_device = device;
            best_score = score;
        }
    }

    return best_device;
}

pub const SwapchainSupport = struct {
    capabilities: vk.api.VkSurfaceCapabilitiesKHR,
    formats: []vk.api.VkSurfaceFormatKHR,
    present_modes: []vk.api.VkPresentModeKHR,
    allocator: std.mem.Allocator,

    /// Query the swapchain support for a physical device.
    ///
    /// The returned `SwapchainSupport` must be deallocated with `deinit`.
    pub fn query(
        allocator: std.mem.Allocator,
        device: vk.api.VkPhysicalDevice,
        surface: vk.api.VkSurfaceKHR,
    ) !SwapchainSupport {
        var capabilities: vk.api.VkSurfaceCapabilitiesKHR = undefined;
        try vk.check(vk.api.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &capabilities));

        var format_count: u32 = 0;
        var present_mode_count: u32 = 0;
        try vk.check(vk.api.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, null));
        try vk.check(vk.api.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null));

        var formats = try allocator.alloc(vk.api.VkSurfaceFormatKHR, format_count);
        var present_modes = try allocator.alloc(vk.api.VkPresentModeKHR, present_mode_count);
        try vk.check(vk.api.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, formats.ptr));
        try vk.check(vk.api.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, present_modes.ptr));

        return .{
            .capabilities = capabilities,
            .formats = formats,
            .present_modes = present_modes,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: SwapchainSupport) void {
        self.allocator.free(self.formats);
        self.allocator.free(self.present_modes);
    }

    pub fn isAdequate(self: SwapchainSupport) bool {
        return self.formats.len != 0 and self.present_modes.len != 0;
    }
};

pub const Queues = struct {
    graphics: u32,
    present: u32,

    pub const COUNT = 2;

    fn isPresentSupported(device: vk.api.VkPhysicalDevice, queue_index: u32, surface: ?vk.api.VkSurfaceKHR) !bool {
        if (surface) |_surface| {
            var presentSupported: vk.api.VkBool32 = vk.api.VK_FALSE;
            const result = vk.api.vkGetPhysicalDeviceSurfaceSupportKHR(
                device,
                queue_index,
                _surface,
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

        var queue_families = try allocator.alloc(vk.api.VkQueueFamilyProperties, count);
        vk.api.vkGetPhysicalDeviceQueueFamilyProperties(device, &count, queue_families.ptr);

        return queue_families;
    }

    fn find(
        allocator: std.mem.Allocator,
        device: vk.api.VkPhysicalDevice,
        surface: ?vk.api.VkSurfaceKHR,
    ) !?Queues {
        var graphics: ?u32 = null;
        var present: ?u32 = null;

        var queue_families = try Queues.getQueueFamilies(allocator, device);
        for (queue_families, 0..) |family, i| {
            var queue_index: u32 = @intCast(i);

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
    pub fn indices(self: Queues) [COUNT]u32 {
        return .{ self.graphics, self.present };
    }
};

fn createDevice(physical: vk.api.VkPhysicalDevice, extensions: []const [*c]const u8, queues: Queues) !vk.api.VkDevice {
    const queueInfo = vk.api.VkDeviceQueueCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = 0,
        .queueCount = 1,
        .pQueuePriorities = &@as(f32, 1.0),
    };

    var queueInfos = [_]vk.api.VkDeviceQueueCreateInfo{queueInfo} ** Queues.COUNT;

    queueInfos[0].queueFamilyIndex = queues.graphics;
    queueInfos[1].queueFamilyIndex = queues.present;

    var features: vk.api.VkPhysicalDeviceFeatures = undefined;
    vk.api.vkGetPhysicalDeviceFeatures(physical, &features);

    const deviceInfo = vk.api.VkDeviceCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = Queues.COUNT,
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

vk: vk.api.VkDevice,
physical: vk.api.VkPhysicalDevice,
queues: Queues,
graphics: vk.Queue,
present: vk.Queue,
allocator: std.mem.Allocator,

pub fn init(
    instance: vk.Instance,
    window: ?Window,
) !Device {
    const surface = if (window) |w| w.surface else null;

    const physical = try findPhysicalDevice(instance.allocator, instance.vk, surface) orelse
        return Error.NoPhysicalDevice;

    const queues = try Queues.find(instance.allocator, physical, surface) orelse
        return Error.NoQueueFamily;

    const device = try createDevice(physical, &REQUIRED_EXTENSIONS, queues);

    const graphics = getQueue(instance.allocator, device, queues.graphics);
    const present = getQueue(instance.allocator, device, queues.present);

    return Device{
        .vk = device,
        .physical = physical,
        .queues = queues,
        .graphics = graphics,
        .present = present,
        .allocator = instance.allocator,
    };
}

pub fn deinit(self: Device) void {
    vk.api.vkDestroyDevice(self.vk, null);
}

pub fn waitIdle(self: Device) !void {
    try vk.check(vk.api.vkDeviceWaitIdle(self.vk));
}

pub fn querySwapchainSupport(self: Device, window: Window) !SwapchainSupport {
    return SwapchainSupport.query(self.allocator, self.physical, window.surface);
}

pub fn queryWindowFormat(self: Device, window: Window) !vk.api.VkFormat {
    const support = try self.querySwapchainSupport(window);
    return vk.Swapchain.pickSurfaceFormat(support.formats).format;
}

pub fn createBuffer(self: Device, desc: vk.Buffer.Descriptor) !vk.Buffer {
    return vk.Buffer.init(self, desc);
}

pub fn createFence(self: Device, signalled: bool) !vk.Fence {
    return vk.Fence.init(self, signalled);
}

pub fn createSemaphore(self: Device) !vk.Semaphore {
    return vk.Semaphore.init(self);
}

pub const BindingResource = union(enum) {
    buffer: vk.Buffer,
    image: vk.Image,

    fn asVk(self: BindingResource) vk.api.VkDescriptorType {
        switch (self) {
            .buffer => return vk.api.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .image => return vk.api.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
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
};

pub fn updateBindGroups(self: Device, desc: UpdateBindGroupsDescriptor) !void {
    const writes = try self.allocator.alloc(vk.api.VkWriteDescriptorSet, desc.writes.len);
    defer self.allocator.free(writes);

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
            .buffer => {
                writes[i].pBufferInfo = &vk.api.VkDescriptorBufferInfo{
                    .buffer = write.resource.buffer.vk,
                    .offset = 0,
                    .range = write.resource.buffer.size,
                };
            },
            .image => {},
        }
    }

    vk.api.vkUpdateDescriptorSets(self.vk, @intCast(writes.len), writes.ptr, 0, null);
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
