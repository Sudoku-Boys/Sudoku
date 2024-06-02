const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");

const Rotate = struct {};

fn testSystem(
    time: *engine.Time,
    query: engine.Query(struct {
        transform: *engine.Transform,
        rotate: *Rotate,
    }),
) !void {
    var it = query.iterator();
    while (it.next()) |q| {
        q.transform.rotation.mulEq(engine.Quat.rotateY(time.dt * 0.2));
    }
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

    const t = try game.addSystem(testSystem);
    t.name("testSystem");
    t.label(engine.Game.Phase.Update);

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
    try box.addComponent(Rotate{});

    mat.increment();
    mesh.increment();

    const box2 = try game.world.spawn();
    try box2.addComponent(mat);
    try box2.addComponent(mesh);
    try box2.addComponent(engine.Transform{
        .translation = engine.Vec3.init(2.0, 0.2, 0.0),
    });
    try box2.addComponent(engine.GlobalTransform{});
    try box2.addComponent(Rotate{});

    try game.world.set_parent(box2.entity, box.entity);

    const camera = try game.world.spawn();
    try camera.addComponent(engine.Camera{});
    try camera.addComponent(engine.Transform{
        .translation = engine.Vec3.init(0.0, 0.0, 10.0),
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
