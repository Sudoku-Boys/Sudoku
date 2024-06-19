const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");
const board = @import("board.zig");
const grass = @import("grass.zig");
const movement = @import("movement.zig");
const audio = @import("audio.zig");

fn startup(
    allocator: std.mem.Allocator,
    commands: engine.Commands,
    meshes: *engine.Assets(engine.Mesh),
    grass_materials: *engine.Assets(grass.Material),
    standard_materials: *engine.Assets(engine.StandardMaterial),
) !void {
    _ = grass_materials;

    const camera = try commands.spawn();
    try camera.addComponent(engine.Camera{});
    try camera.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, 0.0, 10.0),
    });
    try camera.addComponent(engine.GlobalTransform{});

    const grass_mesh = try grass.generateMesh(allocator);
    const grass_mesh_handle = try meshes.add(grass_mesh);

    const grass_material = engine.StandardMaterial{};
    const grass_material_handle = try standard_materials.add(grass_material);

    const grass_ = try commands.spawn();
    try grass_.addComponent(grass_mesh_handle);
    try grass_.addComponent(grass_material_handle);
    try grass_.addComponent(engine.Transform{});
    try grass_.addComponent(engine.GlobalTransform{});

    //Adding movement to the camera
    const winPtr = commands.world.resourcePtr(engine.Window);
    try camera.addComponent(movement.PlayerMovement{
        .mouseSensitivity = 0.3,
        .window = winPtr,
    });

    _ = try board.spawnBoard(commands);
}

pub fn main() !void {
    try engine.Window.initGlfw();
    defer engine.Window.deinitGlfw();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var game = try engine.Game.init(allocator);
    defer game.deinit();

    try game.addPlugin(engine.HirachyPlugin{});
    try game.addPlugin(engine.RenderPlugin{});
    try game.addPlugin(engine.MaterialPlugin(engine.StandardMaterial){});
    try game.addPlugin(engine.MaterialPlugin(grass.Material){});
    try game.addPlugin(audio.Plugin{});

    _ = try game.addSystem(board.boardInputSystem);
    _ = try game.addStartupSystem(startup);

    //Camera movement
    const movecam = try game.addSystem(movement.moveSystem);
    movecam.name("movecam");
    movecam.label(engine.Game.Phase.Update);

    try game.start();

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
