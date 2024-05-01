const std = @import("std");

const EmptySystem = @import("EmptySystem.zig");
const Schedule = @import("Schedule.zig");
const Time = @import("Time.zig");
const TypeId = @import("TypeId.zig");
const World = @import("World.zig");

const asset = @import("asset.zig");
const event = @import("event.zig");
const render = @import("render.zig");

const Game = @This();

pub const Phase = enum {
    Start,
    Update,
    Render,
    End,
};

plugins: std.AutoHashMap(TypeId, void),
schedule: Schedule,
world: World,

pub fn init(alloc: std.mem.Allocator) !Game {
    var game = Game{
        .plugins = std.AutoHashMap(TypeId, void).init(alloc),
        .schedule = Schedule.init(alloc),
        .world = World.init(alloc),
    };

    try game.addPlugin(Time.Plugin{});

    const start_phase = try game.addSystem(EmptySystem{});
    try start_phase.label(Phase.Start);
    try start_phase.before(Phase.Update);

    const update_phase = try game.addSystem(EmptySystem{});
    try update_phase.label(Phase.Update);
    try update_phase.after(Phase.Start);
    try update_phase.before(Phase.Render);

    const render_phase = try game.addSystem(EmptySystem{});
    try render_phase.label(Phase.Render);
    try render_phase.after(Phase.Update);
    try render_phase.before(Phase.End);

    const end_phase = try game.addSystem(EmptySystem{});
    try end_phase.label(Phase.End);
    try end_phase.after(Phase.Render);

    return game;
}

pub fn deinit(self: *Game) void {
    self.plugins.deinit();
    self.schedule.deinit();
    self.world.deinit();
}

pub fn allocator(self: *const Game) std.mem.Allocator {
    return self.world.allocator;
}

pub fn hasPlugin(self: *const Game, comptime T: type) bool {
    return self.plugins.contains(TypeId.of(T));
}

pub fn addPlugin(self: *Game, plugin: anytype) !void {
    const T = @TypeOf(plugin);
    const type_id = TypeId.of(T);

    if (self.hasPlugin(T)) return;
    try self.plugins.put(type_id, {});

    if (!@hasDecl(T, "buildPlugin")) {
        @compileError(std.fmt.comptimePrint(
            "Plugin `{}` does not have a `buildPlugin` function",
            .{T},
        ));
    }

    try plugin.buildPlugin(self);
}

pub fn requirePlugin(self: *const Game, comptime T: type) void {
    if (!self.hasPlugin(T)) {
        std.debug.panic("Plugin `{}` is required but not found", .{T});
    }
}

pub fn addEvent(self: *Game, comptime T: type) !void {
    if (self.world.containsResource(event.Events(T))) return;

    const events = event.Events(T).init(self.world.allocator);
    try self.world.addResource(events);

    const system = try self.addSystem(event.Events(T).system);
    try system.before(Phase.Start);
}

pub fn addAsset(self: *Game, comptime T: type) !void {
    if (self.world.containsResource(asset.Assets(T))) return;

    try self.addEvent(asset.AssetEvent(T));

    const assets = asset.Assets(T).init(self.world.allocator);
    try self.world.addResource(assets);

    const clean = try self.addSystem(asset.Assets(T).clean);
    try clean.after(Phase.End);

    const events = try self.addSystem(asset.Assets(T).sendEvents);
    try events.before(Phase.Start);
}

pub fn addSystem(self: *Game, system: anytype) !Schedule.AddedSystem {
    return self.schedule.addSystem(system);
}

pub fn update(self: *Game) !void {
    try self.schedule.run(&self.world);
}
