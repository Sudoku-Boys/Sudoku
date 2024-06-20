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
    const camera = try commands.spawn();
    try camera.addComponent(engine.Camera{});
    try camera.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, 0.0, 10.0),
    });
    try camera.addComponent(engine.GlobalTransform{});

    const grass_mesh = try grass.generateMesh(allocator);
    const grass_mesh_handle = try meshes.add(grass_mesh);

    const grass_material = grass.Material{};
    const grass_material_handle = try grass_materials.add(grass_material);

    const grass_instances = 6;

    for (0..grass_instances) |i| {
        for (0..grass_instances) |j| {
            const x = (@as(f32, @floatFromInt(i)) - @as(f32, @floatFromInt(grass_instances)) / 2.0) * 50.0;
            const z = (@as(f32, @floatFromInt(j)) - @as(f32, @floatFromInt(grass_instances)) / 2.0) * 50.0;

            grass_mesh_handle.increment();
            grass_material_handle.increment();

            const grass_ = try commands.spawn();
            try grass_.addComponent(grass_mesh_handle);
            try grass_.addComponent(grass_material_handle);
            try grass_.addComponent(engine.Transform{
                .translation = engine.Vec3.init(x, 0.0, z),
            });
            try grass_.addComponent(engine.GlobalTransform{});
        }
    }

    const ground_mesh = try engine.Mesh.plane(allocator, 1000.0, 0xffffffff);
    const ground_mesh_handle = try meshes.add(ground_mesh);

    const ground_material = engine.StandardMaterial{
        .color = engine.Color.rgb(27.0 / 255.0, 73.0 / 255.0, 15.0 / 255.0),
        .roughness = 1.0,
    };
    const ground_material_handle = try standard_materials.add(ground_material);

    const ground = try commands.spawn();
    try ground.addComponent(ground_mesh_handle);
    try ground.addComponent(ground_material_handle);
    try ground.addComponent(engine.Transform{});
    try ground.addComponent(engine.GlobalTransform{});

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

    const grass_system = try game.addSystem(grass.system);
    grass_system.name("grass");
    grass_system.label(engine.Game.Phase.Update);

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
