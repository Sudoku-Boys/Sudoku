const std = @import("std");
const vk = @import("vk.zig");

const Self = @This();

vk: vk.api.VkInstance,
debug_messenger: ?vk.api.VkDebugUtilsMessengerEXT,

pub const Descriptor = struct {
    application_name: []const u8 = "Sudoku",
    application_version: u32 = vk.api.VK_MAKE_VERSION(1, 0, 0),
    layer_names: []const [*c]const u8 = &[_][*c]const u8{
        "VK_LAYER_KHRONOS_validation".ptr,
    },
    extensions: []const [*c]const u8 = &[_][*c]u8{},
};

fn debugCallback(
    messageSeverity: vk.api.VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageType: vk.api.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ?*const vk.api.VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: ?*anyopaque,
) callconv(.C) vk.api.VkBool32 {
    _ = messageType;
    _ = pUserData;

    const message = pCallbackData.?.pMessage;
    switch (messageSeverity) {
        vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => {
            std.log.info("vulkan: {s}", .{message});
        },
        vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => {
            std.log.info("vulkan: {s}", .{message});
        },
        vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => {
            std.log.warn("vulkan: {s}", .{message});
        },
        vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => {
            std.log.err("vulkan: {s}", .{message});
        },
        else => unreachable,
    }
    return vk.api.VK_FALSE;
}

fn createDebugUtilsMessenger(instance: vk.api.VkInstance) !?vk.api.VkDebugUtilsMessengerEXT {
    const debugInfo = vk.api.VkDebugUtilsMessengerCreateInfoEXT{
        .sType = vk.api.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .pNext = null,
        .flags = 0,
        .messageSeverity = vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT |
            vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            vk.api.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = vk.api.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            vk.api.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            vk.api.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = debugCallback,
        .pUserData = null,
    };

    if (vk.api.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")) |f| {
        const createDebugUtilsMessengerEXT: vk.api.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(f);

        var debug_messenger: vk.api.VkDebugUtilsMessengerEXT = undefined;
        const result = createDebugUtilsMessengerEXT.?(instance, &debugInfo, null, &debug_messenger);
        try vk.checkResult(result);

        return debug_messenger;
    } else {
        return null;
    }
}

fn destroyDebugUtilsMessenger(instance: vk.api.VkInstance, debug_messenger: vk.api.VkDebugUtilsMessengerEXT) void {
    if (vk.api.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")) |f| {
        const destroyDebugUtilsMessengerEXT: vk.api.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(f);
        destroyDebugUtilsMessengerEXT.?(instance, debug_messenger, null);
    }
}

fn addRequiredExtensions(al: std.mem.Allocator, extensions: []const [*c]const u8) ![]const [*c]const u8 {
    var requiredExtensions = try al.alloc([*c]const u8, extensions.len + 1);

    for (extensions, 0..) |ext, i| {
        requiredExtensions[i] = ext;
    }

    requiredExtensions[extensions.len] = vk.api.VK_EXT_DEBUG_UTILS_EXTENSION_NAME.ptr;

    return requiredExtensions;
}

pub fn init(desc: Descriptor) !Self {
    const applicationInfo = vk.api.VkApplicationInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = desc.application_name.ptr,
        .applicationVersion = desc.application_version,
        .pEngineName = "Sudoku engine",
        .engineVersion = vk.api.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.api.VK_API_VERSION_1_0,
    };

    var extensions = try addRequiredExtensions(std.heap.c_allocator, desc.extensions);
    defer std.heap.c_allocator.free(extensions);

    const instanceInfo = vk.api.VkInstanceCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &applicationInfo,
        .enabledLayerCount = @intCast(desc.layer_names.len),
        .ppEnabledLayerNames = desc.layer_names.ptr,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
    };

    var instance: vk.api.VkInstance = undefined;
    const result = vk.api.vkCreateInstance(&instanceInfo, null, &instance);
    try vk.checkResult(result);

    const debug_messenger = try createDebugUtilsMessenger(instance);

    return .{
        .vk = instance,
        .debug_messenger = debug_messenger,
    };
}

pub fn deinit(self: Self) void {
    if (self.debug_messenger) |m| {
        destroyDebugUtilsMessenger(self.vk, m);
    }

    vk.api.vkDestroyInstance(self.vk, null);
}
