const std = @import("std");
const Window = @import("engine/window.zig");
const vk = @import("engine/vulkan.zig");

pub fn main() !void {
    try Window.initGlfw();
    defer Window.deinitGlfw();

    const ext = Window.queryVkExtensions();

    var instanceInfo = vk.api.VkInstanceCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = null,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @intCast(ext.len),
        .ppEnabledExtensionNames = ext.ptr,
    };

    var instance: vk.api.VkInstance = undefined;
    var res = vk.api.vkCreateInstance(&instanceInfo, null, &instance);
    try vk.assertSuccess(res);
    defer vk.api.vkDestroyInstance(instance, null);

    const window = try Window.init(.{
        .instance = instance,
    });
    defer window.deinit();

    while (!window.shouldClose()) {
        Window.pollEvents();
    }
}
