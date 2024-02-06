const std = @import("std");
const Window = @import("engine/Window.zig");
const Renderer = @import("engine/render/Renderer.zig");
const vk = @import("vulkan");

const vkm = @import("math/math.zig");

pub fn main() !void {
    try Window.initGlfw();
    defer Window.deinitGlfw();

    const instance = try vk.Instance.init(.{
        .allocator = std.heap.c_allocator,
        .required_extensions = Window.requiredVulkanExtensions(),
    });
    defer instance.deinit();

    const window = try Window.init(.{
        .instance = instance,
    });
    defer window.deinit();

    const device = try vk.Device.init(instance, window.surface);
    defer device.deinit();

    var renderer = try Renderer.init(.{
        .allocator = std.heap.c_allocator,
        .device = device,
        .surface = window.surface,
    });
    defer renderer.deinit();

    while (!window.shouldClose()) {
        Window.pollEvents();
        try renderer.drawFrame();
    }
    
    var v0: vkm.Vec3 = vkm.Vec3.init(1, 2, 3);
    std.debug.print("{}\n", .{v0.v});
}
