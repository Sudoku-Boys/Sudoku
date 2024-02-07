const std = @import("std");
const Window = @import("engine/Window.zig");
const Renderer = @import("engine/render/Renderer.zig");
const vk = @import("vulkan");

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

    const device = try vk.Device.init(.{
        .instance = instance,
        .compatible_surface = window.surface,
    });
    defer device.deinit();

    var renderer = try Renderer.init(.{
        .allocator = std.heap.c_allocator,
        .device = device,
        .surface = window.surface,
    });
    defer renderer.deinit();

    var lastTime: i64 = std.time.milliTimestamp();
    var frames: i64 = 0;
    while (!window.shouldClose()) {
        Window.pollEvents();
        try renderer.drawFrame();
        frames += 1;

        const time = std.time.milliTimestamp();
        if (time - lastTime > 1000) {
            lastTime = time;
            var buffer: [128:0]u8 = undefined;
            const tit = try std.fmt.bufPrint(&buffer, "Sudoku Engine | FPS: {d}", .{frames});
            buffer[tit.len] = 0;
            window.setTitle(tit);
            frames = 0;
        }
    }
}
