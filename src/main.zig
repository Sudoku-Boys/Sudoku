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

    const material = try materials.add(engine.StandardMaterial{
        .color = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 },
    });

    var meshes = engine.Meshes.init(allocator);
    defer meshes.deinit();

    const mesh = try meshes.add(try engine.Mesh.cube(allocator, 1.0, 0xffffffff));

    var scene = engine.Scene.init(allocator);
    defer scene.deinit();

    try scene.objects.append(.{
        .mesh = mesh,
        .material = material,
        .transform = engine.Transform.xyz(-2, 0.0, 0.0),
    });

    try scene.objects.append(.{
        .mesh = mesh,
        .material = material,
        .transform = engine.Transform.xyz(2, 0.0, 0.0),
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
            movement.v -= engine.Vec3.Z.v;
        }

        if (window.isKeyDown('s')) {
            movement.v += engine.Vec3.Z.v;
        }

        if (window.isKeyDown('a')) {
            movement.v -= engine.Vec3.X.v;
        }

        if (window.isKeyDown('d')) {
            movement.v += engine.Vec3.X.v;
        }

        movement = movement.normalize_or_zero().muls(dt * 5.0);
        scene.camera.transform.translation.addEq(movement);

        materials.getPtr(engine.StandardMaterial, material).?.color = .{
            .r = (engine.sin(time) + 1.0) / 2.0,
            .g = (engine.cos(time) + 1.0) / 2.0,
            .b = (engine.sin(time) * engine.cos(time) + 1.0) / 2.0,
            .a = 1.0,
        };

        const axis = engine.vec3(1.0, -2.0, 0.8).normalize();
        const rotation = engine.Quat.rotate(axis, dt);

        for (scene.objects.items, 0..) |*object, i| {
            object.transform.rotation = object.transform.rotation.mul(if (i % 2 == 0) rotation else rotation.inv());
        }
    }
}
