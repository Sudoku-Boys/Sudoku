const std = @import("std");
const Window = @import("engine/window.zig");
const Instance = @import("engine/vulkan/Instance.zig");

pub fn main() !void {
    try Window.initGlfw();
    defer Window.deinitGlfw();

    const instance = try Instance.init(.{
        .extensions = Window.queryVkExtensions(),
    });
    defer instance.deinit();

    const window = try Window.init(.{
        .instance = instance,
    });
    defer window.deinit();

    while (!window.shouldClose()) {
        Window.pollEvents();
    }
}
