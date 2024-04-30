const std = @import("std");

const Game = @import("Game.zig");

pub fn EventId(comptime T: type) type {
    _ = T;
    return struct {
        index: usize,
    };
}

pub fn Events(comptime T: type) type {
    const Entry = struct {
        const Self = @This();

        id: EventId(T),
        event: T,

        pub fn deinit(self: *Self) void {
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
        const Self = @This();

        entries: std.ArrayListUnmanaged(Entry) = .{},
        start_event_count: usize = 0,

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            for (self.entries.items) |*entry| {
                entry.deinit();
            }

            self.entries.deinit(allocator);
        }

        pub fn clear(self: *Self) void {
            for (self.entries.items) |*entry| {
                entry.deinit();
            }

            self.entries.clearRetainingCapacity();
        }
    };

    return struct {
        const Self = @This();

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
