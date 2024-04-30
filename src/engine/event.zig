const std = @import("std");

const Game = @import("Game.zig");
const World = @import("World.zig");

pub fn EventId(comptime T: type) type {
    _ = T;
    return struct {
        index: usize,
    };
}

pub fn Events(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Entry = struct {
            id: EventId(T),
            event: T,

            pub fn deinit(self: *Entry) void {
                switch (@typeInfo(T)) {
                    .Struct, .Enum, .Union, .Opaque => {
                        if (@hasDecl(T, "deinit")) {
                            self.event.deinit();
                        }
                    },
                    else => {},
                }
            }
        };

        const Sequence = struct {
            entries: std.ArrayListUnmanaged(Entry) = .{},
            start_event_count: usize = 0,

            pub fn deinit(self: *Sequence, allocator: std.mem.Allocator) void {
                for (self.entries.items) |*entry| {
                    entry.deinit();
                }

                self.entries.deinit(allocator);
            }

            pub fn clear(self: *Sequence) void {
                for (self.entries.items) |*entry| {
                    entry.deinit();
                }

                self.entries.clearRetainingCapacity();
            }
        };

        allocator: std.mem.Allocator,
        left: Sequence,
        right: Sequence,
        count: usize,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .left = .{},
                .right = .{},
                .count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.left.deinit(self.allocator);
            self.right.deinit(self.allocator);
        }

        pub fn send(self: *Self, event: T) !void {
            const id = EventId(T){ .index = self.count };

            const entry = Entry{
                .id = id,
                .event = event,
            };

            try self.left.entries.append(self.allocator, entry);
            self.count += 1;
        }

        pub fn len(self: Self) usize {
            return self.left.entries.len + self.right.entries.len;
        }

        pub fn is_empty(self: Self) bool {
            return self.len() == 0;
        }

        pub fn flush(self: *Self) void {
            std.mem.swap(Sequence, &self.left, &self.right);
            self.left.clear();
            self.left.start_event_count = self.count;
        }

        pub fn reset(self: *Self) void {
            self.left.start_event_count = self.count;
            self.right.start_event_count = self.count;
        }

        pub fn clear(self: *Self) void {
            self.left.clear();
            self.right.clear();
            self.reset();
        }

        pub fn system(events: *Self) !void {
            events.flush();
        }
    };
}

pub fn EventReader(comptime T: type) type {
    return struct {
        const Self = @This();

        events: *Events(T),
        state: *SystemParamState,

        pub fn next(self: *const Self) ?Events(T).Entry {
            const l_index = self.state.last_event_count -| self.events.left.start_event_count;
            const r_index = self.state.last_event_count -| self.events.right.start_event_count;
            const l = self.events.left.entries.items[l_index..];
            const r = self.events.right.entries.items[r_index..];

            const unread = l.len + r.len;

            self.state.last_event_count = self.events.count - unread;

            if (unread == 0) return null;

            const entry = if (r.len > 0) r[0] else l[0];
            self.state.last_event_count = @max(entry.id.index + 1, self.state.last_event_count);

            return entry;
        }

        pub fn len(self: *const Self) usize {
            return @min(self.events.count -| self.state.last_event_count, self.events.len());
        }

        pub const SystemParamState = struct {
            last_event_count: usize,
        };

        pub fn systemParamInit(world: *World) !SystemParamState {
            _ = world;

            return .{
                .last_event_count = 0,
            };
        }

        pub fn systemParamFetch(world: *World, state: *SystemParamState) !Self {
            return .{
                .events = world.resourcePtr(Events(T)),
                .state = state,
            };
        }

        pub fn systemParamApply(world: *World, state: *SystemParamState) !void {
            _ = state;
            _ = world;
        }
    };
}

pub fn EventWriter(comptime T: type) type {
    return struct {
        const Self = @This();

        events: *Events(T),

        pub fn send(self: *const Self, event: T) !void {
            try self.events.send(event);
        }

        pub const SystemParamState = void;

        pub fn systemParamInit(world: *World) !SystemParamState {
            _ = world;
        }

        pub fn systemParamFetch(world: *World, state: *SystemParamState) !Self {
            _ = state;
            return .{
                .events = world.resourcePtr(Events(T)),
            };
        }

        pub fn systemParamApply(world: *World, state: *SystemParamState) !void {
            _ = world;
            _ = state;
        }
    };
}
