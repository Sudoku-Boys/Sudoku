//The idea with this file is to 'make the game' in the engine, from here.
const std = @import("std");
const vk = @import("vulkan");

const engine = @import("../engine.zig");

//Adds components and objects to the game engine for the sudoku game, from the main function.
pub fn setupGame(game: *engine.Game, allocator: std.mem.Allocator) !void {
    //var game = gamePtr;

    const images = game.world.resourcePtr(engine.Assets(engine.Image));
    const image = try images.add(try engine.Image.load_qoi(allocator, "img.qoi"));
    const normal = try images.add(try engine.Image.load_qoi(allocator, "norm.qoi"));

    const materials = game.world.resourcePtr(engine.Assets(engine.StandardMaterial));
    const mat = try materials.add(engine.StandardMaterial{
        .color_texture = image,
        .normal_map = normal,
        .roughness = 0.9,
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
    //try box.addComponent(Rotate{});

    mat.increment();
    mesh.increment();

    const box2 = try game.world.spawn();
    try box2.addComponent(mat);
    try box2.addComponent(mesh);
    try box2.addComponent(engine.Transform{
        .translation = engine.Vec3.init(2.0, 0.2, 0.0),
    });
    try box2.addComponent(engine.GlobalTransform{});
    //try box2.addComponent(Rotate{});

    try game.world.set_parent(box2.entity, box.entity);

    const camera = try game.world.spawn();
    try camera.addComponent(engine.Camera{});
    try camera.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, 0.0, 10.0),
    });
}
