const std = @import("std");

const World = @import("World.zig");

const System = @This();

vtable: *const VTable,
state: *u8,

pub fn init(allocator: std.mem.Allocator, system: anytype) !System {
    const T = @TypeOf(system);

    var state: *T = undefined;

    if (@sizeOf(T) > 0) {
        state = try allocator.create(T);
        state.* = system;
    }

    return System{
        .vtable = VTable.of(T),
        .state = @ptrCast(@alignCast(state)),
    };
}

pub fn deinit(self: System, allocator: std.mem.Allocator) void {
    if (self.vtable.deinit) |deinit_state| {
        deinit_state(self.state, allocator);
    }
}

pub fn run(self: System, world: *World) !void {
    try self.vtable.run(self.state, world);
}

pub const VTable = struct {
    deinit: ?*const fn (*u8, std.mem.Allocator) void,
    run: *const fn (*u8, *World) anyerror!void,

    pub fn of(comptime T: type) *const VTable {
        return &.{
            .deinit = Closure(T).deinit,
            .run = Closure(T).run,
        };
    }

    fn Closure(comptime T: type) type {
        return struct {
            pub fn deinit(state: *u8, allocator: std.mem.Allocator) void {
                const state_ptr: *T = @ptrCast(@alignCast(state));

                if (comptime @hasDecl(T, "deinit")) {
                    state_ptr.deinit();
                }

                if (@sizeOf(T) > 0) {
                    allocator.destroy(state_ptr);
                }
            }

            pub fn run(state: *u8, world: *World) anyerror!void {
                const state_ptr: *T = @ptrCast(@alignCast(state));
                try state_ptr.run(world);
            }
        };
    }
};
