const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vk.zig");

const Instance = @This();

// a callback function to handle debug messages from the validation layers
fn debugCallback(
    messageSeverity: vk.api.VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageType: vk.api.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ?*const vk.api.VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: ?*anyopaque,
) callconv(.C) vk.api.VkBool32 {
    _ = messageType;
    _ = pUserData;

    std.debug.assert(pCallbackData != null);
    const message = pCallbackData.?.pMessage;

    // print the message to the console
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

// create a debug messenger to handle validation layer messages
fn createDebugUtilsMessenger(instance: vk.api.VkInstance) !?vk.api.VkDebugUtilsMessengerEXT {
    // enable all message types
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

    // if the extension is available, create the messenger
    if (vk.api.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")) |f| {
        const createDebugUtilsMessengerEXT: vk.api.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(f);

        var debug_messenger: vk.api.VkDebugUtilsMessengerEXT = undefined;
        const result = createDebugUtilsMessengerEXT.?(instance, &debugInfo, null, &debug_messenger);
        try vk.check(result);

        return debug_messenger;
    } else {
        return null;
    }
}

// destroy the debug messenger
fn destroyDebugUtilsMessenger(instance: vk.api.VkInstance, debug_messenger: vk.api.VkDebugUtilsMessengerEXT) void {
    // if the extension is available, destroy the messenger
    if (vk.api.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")) |f| {
        const destroyDebugUtilsMessengerEXT: vk.api.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(f);
        destroyDebugUtilsMessengerEXT.?(instance, debug_messenger, null);
    }
}

// return the required validation layers
// this is dependent on the build mode
fn requiredLayers() []const [*c]const u8 {
    if (builtin.mode == .Debug) {
        return &[_][*c]const u8{
            "VK_LAYER_KHRONOS_validation",
        };
    } else {
        return &[_][*c]const u8{};
    }
}

// return the required extensions
// this is dependent on the build mode
fn requiredExtensions() []const [*c]const u8 {
    if (builtin.mode == .Debug) {
        return &[_][*c]const u8{
            vk.api.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
        };
    } else {
        return &[_][*c]const u8{
            vk.api.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME,
        };
    }
}

// append two arrays of strings
fn appendStrings(
    allocator: std.mem.Allocator,
    a: []const [*c]const u8,
    b: []const [*c]const u8,
) ![]const [*c]const u8 {
    var strings = try allocator.alloc([*c]const u8, a.len + b.len);

    for (a, 0..) |extension, i| {
        strings[i] = extension;
    }

    for (b, a.len..) |extension, i| {
        strings[i] = extension;
    }

    return strings;
}

// the descriptor for the instance
pub const Descriptor = struct {
    application_name: []const u8 = "Sudoku",
    application_version: u32 = vk.api.VK_MAKE_VERSION(1, 0, 0),
    layer_names: []const [*c]const u8 = &[_][*c]const u8{},
    extensions: []const [*c]const u8 = &[_][*c]const u8{},
};

vk: vk.api.VkInstance,
debug_messenger: ?vk.api.VkDebugUtilsMessengerEXT,
allocator: std.mem.Allocator,

// initialize the instance
//
// this creates the instance and the debug messenger
pub fn init(allocator: std.mem.Allocator, desc: Descriptor) !Instance {
    const application_info = vk.api.VkApplicationInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = desc.application_name.ptr,
        .applicationVersion = desc.application_version,
        .pEngineName = "Sudoku engine",
        .engineVersion = vk.api.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.api.VK_API_VERSION_1_0,
    };

    var layers = try appendStrings(allocator, desc.layer_names, requiredLayers());
    var extensions = try appendStrings(allocator, desc.extensions, requiredExtensions());
    defer allocator.free(layers);
    defer allocator.free(extensions);

    const instance_info = vk.api.VkInstanceCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = vk.api.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR,
        .pApplicationInfo = &application_info,
        .enabledLayerCount = @intCast(layers.len),
        .ppEnabledLayerNames = layers.ptr,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
    };

    var instance: vk.api.VkInstance = undefined;
    const result = vk.api.vkCreateInstance(&instance_info, null, &instance);
    try vk.check(result);

    var debug_messenger: ?vk.api.VkDebugUtilsMessengerEXT = null;

    if (builtin.mode == .Debug) {
        debug_messenger = try createDebugUtilsMessenger(instance);
    }

    return .{
        .vk = instance,
        .debug_messenger = debug_messenger,
        .allocator = allocator,
    };
}

pub fn deinit(self: Instance) void {
    if (self.debug_messenger) |m| {
        destroyDebugUtilsMessenger(self.vk, m);
    }

    vk.api.vkDestroyInstance(self.vk, null);
}
