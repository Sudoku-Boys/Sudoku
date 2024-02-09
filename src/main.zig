const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");

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

    var materials = engine.Materials.init(allocator);
    defer materials.deinit();

    const ground = try materials.add(engine.StandardMaterial{
        .color = engine.Color.WHITE,
    });

    const flashing = try materials.add(engine.StandardMaterial{
        .color = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 },
    });

    var meshes = engine.Meshes.init(allocator);
    defer meshes.deinit();

    const plane = try meshes.add(try engine.Mesh.plane(allocator, 20.0, 0xffffffff));
    const cube = try meshes.add(try engine.Mesh.cube(allocator, 1.0, 0xffffffff));

    var scene = engine.Scene.init(allocator);
    defer scene.deinit();

    try scene.objects.append(.{
        .mesh = plane,
        .material = ground,
        .transform = engine.Transform.xyz(0, -2, 0),
    });

    try scene.objects.append(.{
        .mesh = cube,
        .material = flashing,
        .transform = engine.Transform.xyz(-2, 0, 0),
    });

    try scene.objects.append(.{
        .mesh = cube,
        .material = flashing,
        .transform = engine.Transform.xyz(2, 0, 0),
    });

    var renderer = try engine.Renderer.init(.{
        .allocator = allocator,
        .device = device,
        .surface = window.surface,
        .present_mode = .Fifo,
    });
    defer renderer.deinit();

    try renderer.addMaterial(engine.StandardMaterial);

    var frame_timer = try std.time.Timer.start();
    var time: f32 = 0.0;

    var mouse_position = window.mousePosition();
    var camera_direction = engine.Vec2.ZERO;

    while (!window.shouldClose()) {
        engine.Window.pollEvents();
        try renderer.drawFrame(
            materials,
            meshes,
            scene,
        );

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
        movement = scene.camera.transform.rotation.inv().mul(movement);
        scene.camera.transform.translation.addEq(movement);

        const mouse_delta = window.mousePosition().sub(mouse_position);
        mouse_position = window.mousePosition();

        if (window.isMouseDown(0)) {
            camera_direction = camera_direction.add(mouse_delta.mul(0.001));

            const rotX = engine.Quat.rotateY(camera_direction._.x);
            const rotY = engine.Quat.rotateX(camera_direction._.y);

            scene.camera.transform.rotation = rotY.mul(rotX);
        }

        materials.getPtr(engine.StandardMaterial, flashing).?.color = .{
            .r = (engine.sin(time) + 1.0) / 2.0,
            .g = (engine.cos(time) + 1.0) / 2.0,
            .b = (engine.sin(time) * engine.cos(time) + 1.0) / 2.0,
            .a = 1.0,
        };

        const axis = engine.vec3(1.0, -2.0, 0.8).normalize();
        const rotation = engine.Quat.rotate(axis, dt);

        for (scene.objects.items[1..], 1..) |*object, i| {
            object.transform.rotation = object.transform.rotation.mul(if (i % 2 == 0) rotation else rotation.inv());
        }
    }
}
