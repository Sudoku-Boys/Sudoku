const std = @import("std");

const Time = @This();

start: std.time.Instant,
frame: std.time.Instant,
dt: f32,

pub fn init() !Time {
    return .{
        .start = try std.time.Instant.now(),
        .frame = try std.time.Instant.now(),
    };
}

pub fn update(self: *Time) !void {
    const now = try std.time.Instant.now();
    const dt_ns: f32 = @floatFromInt(now.since(self.frame));
    const dt: f32 = dt_ns / std.time.ns_per_s;

    self.dt = dt;
    self.frame = now;
}
