const std = @import("std");

const Game = @import("Game.zig");
const Time = @This();

start: std.time.Instant,
frame: std.time.Instant,
dt: f32,

pub fn init() !Time {
    return .{
        .start = try std.time.Instant.now(),
        .frame = try std.time.Instant.now(),
        .dt = 0.0,
    };
}

pub fn update(self: *Time) !void {
    const now = try std.time.Instant.now();
    const dt_ns: f32 = @floatFromInt(now.since(self.frame));
    const dt: f32 = dt_ns / std.time.ns_per_s;

    self.dt = dt;
    self.frame = now;
}

pub const Plugin = struct {
    fn system(
        time: *Time,
    ) !void {
        try time.update();
    }

    pub fn buildPlugin(self: Plugin, game: *Game) !void {
        _ = self;

        try game.world.addResource(try Time.init());

        const s = try game.addSystem(system);
        try s.before(Game.Phase.Start);
    }
};
