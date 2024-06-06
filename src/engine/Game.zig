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
startup: Schedule,
schedule: Schedule,
world: World,

pub fn init(alloc: std.mem.Allocator) !Game {
    var game = Game{
        .plugins = std.AutoHashMap(TypeId, void).init(alloc),
        .startup = Schedule.init(alloc),
        .schedule = Schedule.init(alloc),
        .world = World.init(alloc),
    };

    try game.addPlugin(Time.Plugin{});

    const start_phase = try game.addSystem(EmptySystem{});
    start_phase.name("Start");
    start_phase.label(Phase.Start);
    start_phase.before(Phase.Update);

    const update_phase = try game.addSystem(EmptySystem{});
    update_phase.name("Update");
    update_phase.label(Phase.Update);
    update_phase.after(Phase.Start);
    update_phase.before(Phase.Render);

    const render_phase = try game.addSystem(EmptySystem{});
    render_phase.name("Render");
    render_phase.label(Phase.Render);
    render_phase.after(Phase.Update);
    render_phase.before(Phase.End);

    const end_phase = try game.addSystem(EmptySystem{});
    end_phase.name("End");
    end_phase.label(Phase.End);
    end_phase.after(Phase.Render);

    return game;
}

pub fn deinit(self: *Game) void {
    self.plugins.deinit();
    self.startup.deinit();
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
    system.name(std.fmt.comptimePrint("Event: {}", .{T}));
    system.before(Phase.Start);
}

pub fn addAsset(self: *Game, comptime T: type) !void {
    if (self.world.containsResource(asset.Assets(T))) return;

    try self.addEvent(asset.AssetEvent(T));

    const assets = asset.Assets(T).init(self.world.allocator);
    try self.world.addResource(assets);

    const clean = try self.addSystem(asset.Assets(T).clean);
    clean.name(std.fmt.comptimePrint("Clean: {}", .{T}));
    clean.after(Phase.End);

    const events = try self.addSystem(asset.Assets(T).sendEvents);
    events.name(std.fmt.comptimePrint("AssetEvents: {}", .{T}));
    events.before(Phase.Start);
}

pub fn addSystem(self: *Game, system: anytype) !Schedule.AddedSystem {
    return self.schedule.addSystem(system);
}

pub fn addStartupSystem(self: *Game, system: anytype) !Schedule.AddedSystem {
    return self.startup.addSystem(system);
}

pub fn start(self: *Game) !void {
    try self.startup.run(&self.world);
}

pub fn update(self: *Game) !void {
    try self.schedule.run(&self.world);
}
