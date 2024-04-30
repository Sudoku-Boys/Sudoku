const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");

pub fn main() !void {
    try engine.Window.initGlfw();
    defer engine.Window.deinitGlfw();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var game = try engine.Game.init(allocator);
    defer game.deinit();

    try game.addPlugin(engine.RenderPlugin{});
    try game.addPlugin(engine.MaterialPlugin(engine.StandardMaterial){});

    const materials = game.world.resourcePtr(engine.Assets(engine.StandardMaterial));
    const mat = try materials.add(engine.StandardMaterial{});

    const meshes = game.world.resourcePtr(engine.Assets(engine.Mesh));
    const mesh = try meshes.add(try engine.Mesh.cube(allocator, 1.0, 0xffffffff));

    const box = try game.world.addEntity();
    try box.addComponent(mat);
    try box.addComponent(mesh);
    try box.addComponent(engine.Transform{});

    const camera = try game.world.addEntity();
    try camera.addComponent(engine.Camera{});
    try camera.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, 0.0, 5.0),
    });

    while (true) {
        engine.Window.pollEvents();

        const window = game.world.resource(engine.Window);

        if (window.shouldClose()) {
            break;
        }

        try game.update();
    }

    const device = game.world.resource(vk.Device);
    try device.waitIdle();
}
