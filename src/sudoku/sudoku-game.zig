//The idea with this file is to 'make the game' in the engine, from here.

const std = @import("std");

const engine = @import("../engine.zig");
const sudokuComponent = @import("sudokuComponent.zig");
const movement = @import("movement.zig");

//Adds components and objects to the game engine for the sudoku game, from the main function.
pub fn setupGame(game: *engine.Game, allocator: std.mem.Allocator) !void {
    const materials = game.world.resourcePtr(engine.Assets(engine.StandardMaterial));
    const mat = try materials.add(engine.StandardMaterial{
        .color = engine.Color.LIGHT_GRAY,
        .roughness = 0.5,
        .subsurface = 0.1,
        .clearcoat = 0.2,
    });

    //This system is to be replaced by the sudoku system
    const t = try game.addSystem(sudokuComponent.testSystem);
    t.name("testSystem");
    t.label(engine.Game.Phase.Update);

    const meshes = game.world.resourcePtr(engine.Assets(engine.Mesh));
    const mesh = try meshes.add(try engine.Mesh.cube(allocator, 1.0, 0xffffffff));

    //test box
    const box2 = try game.world.spawn();
    try box2.addComponent(mat);
    try box2.addComponent(mesh);
    try box2.addComponent(engine.Transform{
        .translation = engine.Vec3.init(-3.0, 3.0, 0.0),
    });
    try box2.addComponent(engine.GlobalTransform{});
    try box2.addComponent(sudokuComponent.Rotate{});

    mat.increment();
    mesh.increment();

    //The sudoku controller has no mesh, but has the logic.
    const sudokuController = try game.world.spawn();
    try sudokuController.addComponent(engine.GlobalTransform{});
    try sudokuController.addComponent(engine.Transform{
        //The sudoku's midtpoint
        .translation = engine.Vec3.init(0.0, 2.0, 0.0),
    });
    try game.world.set_parent(box2.entity, sudokuController.entity);

    //We make a 9x9 sudoku grid
    //const sudokuCubes = [_]*const engine.EntityRef{&try game.world.spawn()} ** 81;
    var sudokuCubes = std.ArrayList(*const engine.EntityRef).init(allocator);
    defer sudokuCubes.deinit();

    for (0..9) |i| {
        for (0..9) |j| {
            //const index = i * 9 + j;
            //std.debug.print("Index: {}, Pointer: {} \n", .{ index, sudokuCubes[index] });
            const sCube = try game.world.spawn();
            try sCube.addComponent(mat);
            try sCube.addComponent(mesh);
            try sCube.addComponent(engine.Transform{
                .translation = engine.Vec3.init(@floatFromInt(i), @floatFromInt(j), 0.0).mul(0.3),
                .scale = engine.vec3(0.1, 0.1, 0.1),
            });
            try sCube.addComponent(engine.GlobalTransform{});
            try sCube.addComponent(sudokuComponent.Rotate{});
            try game.world.set_parent(sCube.entity, sudokuController.entity);

            mat.increment();
            mesh.increment();

            try sudokuCubes.append(&sCube);
        }
    }

    //Adds some ground to stand on
    const ground = try game.world.spawn();
    try ground.addComponent(mat);
    try ground.addComponent(try meshes.add(try engine.Mesh.plane(allocator, 10.0, 0xffffffff)));
    try ground.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, -2.0, 0.0),
    });
    try ground.addComponent(engine.GlobalTransform{});

    //Camera and movement
    const movecam = try game.addSystem(movement.moveSystem);
    movecam.name("movecam");
    movecam.label(engine.Game.Phase.Update);

    const camera = try game.world.spawn();
    try camera.addComponent(engine.Camera{});
    try camera.addComponent(engine.Transform{
        .translation = engine.Vec3.init(2.0, 3.0, 10.0),
    });

    const winPtr = game.world.resourcePtr(engine.Window);
    try camera.addComponent(movement.moveInfo{ .mouseSensitivity = 0.3, .window = winPtr });
}
