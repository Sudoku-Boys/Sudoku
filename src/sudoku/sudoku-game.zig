//The idea with this file is to 'make the game' in the engine, from here.
const std = @import("std");
const vk = @import("vulkan");

const engine = @import("../engine.zig");

//Adds components and objects to the game engine for the sudoku game, from the main function.
pub fn setupGame(game: *engine.Game, allocator: std.mem.Allocator) !void {
    const materials = game.world.resourcePtr(engine.Assets(engine.StandardMaterial));
    const mat = try materials.add(engine.StandardMaterial{
        .color = engine.Color.LIGHT_GRAY,
        .roughness = 0.5,
        .subsurface = 0.1,
        .clearcoat = 0.2,
    });

    const meshes = game.world.resourcePtr(engine.Assets(engine.Mesh));
    const mesh = try meshes.add(try engine.Mesh.cube(allocator, 1.0, 0xffffffff));

    const box = try game.world.spawn();
    try box.addComponent(mat);
    try box.addComponent(mesh);
    try box.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, -0.2, 0.0),
    });
    try box.addComponent(engine.GlobalTransform{});

    mat.increment();
    mesh.increment();

    const box2 = try game.world.spawn();
    try box2.addComponent(mat);
    try box2.addComponent(mesh);
    try box2.addComponent(engine.Transform{
        .translation = engine.Vec3.init(2.0, 0.2, 1.0),
    });
    try box2.addComponent(engine.GlobalTransform{});

    //TODO: add lighting. Something something renderstuff dot engine dot magter_det_ikke
    //const sky = try game.world.spawn();
    //try sky.addComponent(engine.RenderPlugin.Sky{});

    const camera = try game.world.spawn();
    try camera.addComponent(engine.Camera{});
    try camera.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, 0.0, 10.0),
    });
}
