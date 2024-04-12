const std = @import("std");

const Schedule = @import("Schedule.zig");
const World = @import("World.zig");

const render = @import("render.zig");

const Game = @This();

plugins: std.AutoHashMap(std.builtin.TypeId, void),
schedule: Schedule,
world: World,

pub fn init(allocator: std.mem.Allocator) Game {
    return .{
        .plugins = std.AutoHashMap(std.builtin.TypeId, void).init(allocator),
        .schedule = Schedule.init(allocator),
        .world = World.init(allocator),
    };
}

pub fn deinit(self: *Game) void {
    self.schedule.deinit();
    self.world.deinit();
}

pub fn addPlugin(self: *Game, plugin: anytype) !void {
    const T = @TypeOf(plugin);
    const type_id = std.meta.activeTag(@typeInfo(T));

    if (self.plugins.contains(type_id)) return;
    try self.plugins.put(type_id, {});

    if (@hasDecl(T, "buildPlugin")) {
        @compileError("Plugin does not have a `buildPlugin` function");
    }

    try plugin.builtPlugin(self);
}

pub fn addSystem(self: *Game, system: anytype) !Schedule.AddedSystem {
    return self.schedule.addSystem(system);
}
