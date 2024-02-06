const std = @import("std");
const ecs = @import("engine/ecs.zig");
const Window = @import("engine/Window.zig");
const Renderer = @import("engine/render/Renderer.zig");
const vk = @import("vulkan");

fn testSystem(
    res: ecs.Res(*u32),
    q: ecs.Query(struct { entity: ecs.Entity, num: u32 }, .{bool}),
) !void {
    std.debug.print("\n", .{});
    std.debug.print("Resource: {?}\n", .{res.item.*});

    res.item.* += 1;

    var it = q.iterator();
    while (it.next()) |qu| {
        std.debug.print("System: {?}\n", .{qu});
    }
}

pub fn main() !void {
    try Window.initGlfw();
    defer Window.deinitGlfw();

    var world = ecs.World.init(std.heap.c_allocator);
    defer world.deinit();

    const a = try world.allocEntity();
    try world.addComponent(a, @as(u32, 42));
    try world.addComponent(a, true);

    const b = try world.allocEntity();
    try world.addComponent(b, @as(u32, 43));

    try world.addResource(@as(u32, 123));

    const s = ecs.System.init(testSystem);
    try s.run(&world);

    if (true) return;

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
}
