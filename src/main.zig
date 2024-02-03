const std = @import("std");
const Window = @import("engine/Window.zig");
const Renderer = @import("engine/Renderer.zig");

pub fn main() !void {
    try Window.initGlfw();
    defer Window.deinitGlfw();

    var renderer = try Renderer.init(std.heap.c_allocator);
    defer renderer.deinit();

    while (!renderer.window.shouldClose()) {
        Window.pollEvents();
        try renderer.drawFrame();
    }
}
