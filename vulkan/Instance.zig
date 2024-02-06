const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vk.zig");

const Instance = @This();

pub const Error = error{
    RequiredLayerNotAvailable,
    RequiredExtensionNotAvailable,
};

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

const DEBUG_LAYERS: []const [*c]const u8 = &.{
    "VK_LAYER_KHRONOS_validation",
};

const DEBUG_EXTENSIONS: []const [*c]const u8 = &.{
    vk.api.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
};

// return the required validation layers
// this is dependent on the build mode
fn requiredLayers() []const [*c]const u8 {
    return &.{};
}

// return the required extensions
// this is dependent on the build mode
fn requiredExtensions() []const [*c]const u8 {
    return &.{};
}

fn desiredLayers() []const [*c]const u8 {
    if (builtin.mode == .Debug) {
        return DEBUG_LAYERS;
    }

    return &.{};
}

fn desiredExtensions() []const [*c]const u8 {
    if (builtin.mode == .Debug) {
        return DEBUG_EXTENSIONS;
    }

    return &.{};
}

fn maybeCreateDebugUtilsMessenger(instance: vk.api.VkInstance) !?vk.api.VkDebugUtilsMessengerEXT {
    if (builtin.mode == .Debug) {
        return try createDebugUtilsMessenger(instance);
    }

    return null;
}

fn isNameEq(available: [256]u8, extension: [*c]const u8) bool {
    const available_len = std.mem.len(@as([*c]const u8, &available));
    const extension_len = std.mem.len(extension);

    return std.mem.eql(u8, available[0..available_len], extension[0..extension_len]);
}

fn isLayerAvailable(available: []const vk.api.VkLayerProperties, name: [*c]const u8) bool {
    for (available) |layer| {
        if (isNameEq(layer.layerName, name)) {
            return true;
        }
    }

    return false;
}

/// Check if `layers` are available on the system.
pub fn areLayersAvailable(allocator: std.mem.Allocator, layers: []const [*c]const u8) !bool {
    var count: u32 = 0;
    try vk.check(vk.api.vkEnumerateInstanceLayerProperties(&count, null));

    var available = try allocator.alloc(vk.api.VkLayerProperties, count);
    defer allocator.free(available);

    try vk.check(vk.api.vkEnumerateInstanceLayerProperties(&count, available.ptr));

    for (layers) |layer| {
        if (!isLayerAvailable(available, layer)) {
            return false;
        }
    }

    return true;
}

/// Get the list of layers to enable for the instance.
///
/// Ensuring that `required` and `requiredLayers` are available,
/// and adding `desiredLayers` when available.
fn getLayers(allocator: std.mem.Allocator, required: []const [*c]const u8) ![]const [*c]const u8 {
    var layers = std.ArrayList([*c]const u8).init(allocator);
    errdefer layers.deinit();

    try layers.appendSlice(requiredExtensions());
    try layers.appendSlice(required);

    if (!try areExtensionsAvailable(allocator, layers.items)) {
        std.log.err("Required layers not available:", .{});

        for (layers.items) |layer| {
            std.log.err("  {s}", .{layer});
        }
        return error.RequiredLayerNotAvailable;
    }

    if (try areExtensionsAvailable(allocator, desiredLayers())) {
        try layers.appendSlice(desiredLayers());
    }

    return try layers.toOwnedSlice();
}

fn isExtensionAvailable(available: []const vk.api.VkExtensionProperties, name: [*c]const u8) bool {
    for (available) |ext| {
        if (isNameEq(ext.extensionName, name)) {
            return true;
        }
    }

    return false;
}

/// Check if `extensions` are available on the system.
pub fn areExtensionsAvailable(allocator: std.mem.Allocator, extensions: []const [*c]const u8) !bool {
    var count: u32 = 0;
    try vk.check(vk.api.vkEnumerateInstanceExtensionProperties(null, &count, null));

    var available = try allocator.alloc(vk.api.VkExtensionProperties, count);
    defer allocator.free(available);

    try vk.check(vk.api.vkEnumerateInstanceExtensionProperties(null, &count, available.ptr));

    for (extensions) |ext| {
        if (!isExtensionAvailable(available, ext)) {
            return false;
        }
    }

    return true;
}

/// Get the list of extensions to enable for the instance.
///
/// Ensuring that `required` and `requiredExtensions` are available,
/// and adding `desiredExtensions` when available.
fn getExtensions(allocator: std.mem.Allocator, required: []const [*c]const u8) ![]const [*c]const u8 {
    var extensions = std.ArrayList([*c]const u8).init(allocator);
    errdefer extensions.deinit();

    try extensions.appendSlice(requiredExtensions());
    try extensions.appendSlice(required);

    if (!try areExtensionsAvailable(allocator, extensions.items)) {
        std.log.err("Required extensions not available:", .{});

        for (extensions.items) |extension| {
            std.log.err("  {s}", .{extension});
        }

        return error.RequiredExtensionNotAvailable;
    }

    if (try areExtensionsAvailable(allocator, desiredExtensions())) {
        try extensions.appendSlice(desiredExtensions());
    }

    return try extensions.toOwnedSlice();
}

// the descriptor for the instance
pub const Descriptor = struct {
    allocator: std.mem.Allocator,
    application_name: []const u8 = "Sudoku",
    application_version: u32 = vk.api.VK_MAKE_VERSION(1, 0, 0),
    required_layers: []const [*c]const u8 = &[_][*c]const u8{},
    required_extensions: []const [*c]const u8 = &[_][*c]const u8{},

    fn applicationInfo(self: Descriptor) vk.api.VkApplicationInfo {
        return vk.api.VkApplicationInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = self.application_name.ptr,
            .applicationVersion = self.application_version,
            .pEngineName = "Sudoku engine",
            .engineVersion = vk.api.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.api.VK_API_VERSION_1_0,
        };
    }
};

fn instanceInfo(
    appInfo: *const vk.api.VkApplicationInfo,
    layers: []const [*c]const u8,
    extensions: []const [*c]const u8,
) vk.api.VkInstanceCreateInfo {
    return vk.api.VkInstanceCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = appInfo,
        .enabledLayerCount = @intCast(layers.len),
        .ppEnabledLayerNames = layers.ptr,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
    };
}

vk: vk.api.VkInstance,
debug_messenger: ?vk.api.VkDebugUtilsMessengerEXT,
allocator: std.mem.Allocator,

/// Initialize a new Vulkan instance.
///
/// # Parameters
/// - `allocator` is the allocator to use for all objects created by the instance.
///     this should be a general purpose allocator, and is used for temporary allocations.
pub fn init(desc: Descriptor) !Instance {
    const layers = try getLayers(desc.allocator, desc.required_layers);
    defer desc.allocator.free(layers);

    const extensions = try getExtensions(desc.allocator, desc.required_extensions);
    defer desc.allocator.free(extensions);

    const application_info = desc.applicationInfo();
    const instance_info = instanceInfo(&application_info, layers, extensions);

    var instance: vk.api.VkInstance = undefined;
    try vk.check(vk.api.vkCreateInstance(&instance_info, null, &instance));

    const debug_messenger = try maybeCreateDebugUtilsMessenger(instance);

    return .{
        .vk = instance,
        .debug_messenger = debug_messenger,
        .allocator = desc.allocator,
    };
}

pub fn deinit(self: Instance) void {
    if (self.debug_messenger) |m| destroyDebugUtilsMessenger(self.vk, m);
    vk.api.vkDestroyInstance(self.vk, null);
}
