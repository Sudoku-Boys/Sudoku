const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");

fn systemA(
    res: engine.Res(u32),
) !void {
    std.debug.print("A {}\n", .{res.get()});
}

fn systemB() !void {
    std.debug.print("B\n", .{});
}

const TestLabel = enum {
    A,
    B,
};

pub fn main() !void {
    try engine.Window.initGlfw();
    defer engine.Window.deinitGlfw();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const instance = try vk.Instance.init(.{
        .allocator = allocator,
        .required_extensions = engine.Window.requiredVulkanExtensions(),
    });
    defer instance.deinit();

    const window = try engine.Window.init(.{
        .instance = instance,
    });
    defer window.deinit();

    const device = try vk.Device.init(.{
        .instance = instance,
        .compatible_surface = window.surface,
    });
    defer device.deinit();

    var game = engine.Game.init(allocator);
    defer game.deinit();

    try game.world.addResource(@as(u32, 123));

    _ = try game.world.createEntity();

    const test_a = try game.schedule.addSystem(systemA);
    try test_a.label(TestLabel.A);

    const test_b = try game.schedule.addSystem(systemB);
    try test_b.label(TestLabel.B);
    try test_b.before(TestLabel.A);

    try game.schedule.run(&game.world);

    //var materials = engine.Materials.init(allocator);

    //const ground = try materials.add(engine.StandardMaterial{
    //    .color = engine.Color.WHITE,
    //});

    //const left = try materials.add(engine.StandardMaterial{
    //    .color = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 },
    //    .transmission = 0.9,
    //    .roughness = 0.25,
    //});

    //const right = try materials.add(engine.StandardMaterial{
    //    .color = .{ .r = 0.9, .g = 0.7, .b = 0.6, .a = 1.0 },
    //    .roughness = 0.5,
    //});

    var meshes = engine.Assets(engine.Mesh).init(allocator);

    const plane = try meshes.add(try engine.Mesh.plane(allocator, 20.0, 0xffffffff));
    _ = plane;
    const cube = try meshes.add(try engine.Mesh.cube(allocator, 1.0, 0xffffffff));
    _ = cube;

    //try e.world.addResource(materials);
    try game.world.addResource(meshes);
    //var renderer = try engine.Renderer.init(.{
    //    .allocator = allocator,
    //    .device = device,
    //    .surface = window.surface,
    //    .present_mode = .Immediate,
    //});
    //defer renderer.deinit();

    //try renderer.addMaterial(engine.StandardMaterial);

    var frame_timer = try std.time.Timer.start();
    var time: f32 = 0.0;

    var mouse_position = window.mousePosition();
    var camera_direction = engine.Vec2.ZERO;

    var grabbed: bool = false;

    while (!window.shouldClose()) {
        engine.Window.pollEvents();
        //try renderer.drawFrame(
        //    e.world.resource(engine.Assets(engine.Mesh)),
        //    e.world.resource(engine.Materials),
        //    scene,
        //);

        const dt: f32 = @as(f32, @floatFromInt(frame_timer.lap())) / std.time.ns_per_s;
        time += dt;

        var movement = engine.Vec3.ZERO;

        if (window.isKeyDown('w')) {
            movement.subEq(engine.Vec3.Z);
        }
        if (window.isKeyDown('s')) {
            movement.addEq(engine.Vec3.Z);
        }
        if (window.isKeyDown('a')) {
            movement.subEq(engine.Vec3.X);
        }
        if (window.isKeyDown('d')) {
            movement.addEq(engine.Vec3.X);
        }
        if (window.isKeyDown(' ')) {
            movement.addEq(engine.Vec3.Y);
        }
        if (window.isKeyDown('c')) {
            movement.subEq(engine.Vec3.Y);
        }

        movement = movement.normalize_or_zero().muls(dt * 5.0);

        const mouse_delta = window.mousePosition().sub(mouse_position);
        mouse_position = window.mousePosition();

        if (window.isMouseDown(0)) {
            grabbed = true;
            window.cursorDisabled();
        } else if (window.isMouseDown(1)) {
            grabbed = false;
            window.cursorNormal();
        }

        if (grabbed) {
            camera_direction = camera_direction.add(mouse_delta.mul(0.001));

            const rotX = engine.Quat.rotateY(camera_direction._.x);
            _ = rotX;
            const rotY = engine.Quat.rotateX(camera_direction._.y);
            _ = rotY;
        }

        const axis = engine.vec3(1.0, -2.0, 0.8).normalize();
        const rotation = engine.Quat.rotate(axis, dt);
        _ = rotation;
    }
}
