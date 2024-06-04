const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");
const sudokuGame = @import("sudoku/sudoku-game.zig");

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

    try sudokuGame.setupGame(&game, allocator);

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
