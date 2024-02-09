const std = @import("std");
const OpagueWrapper = @import("OpagueWrapper.zig");

const IdType = struct {
    index: usize,
    generation: u32,
};

fn InternalMap(comptime Id: type, comptime Entry: type, comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        entries: std.ArrayList(?Entry),
        free_list: std.ArrayList(Id),

        pub fn init(allocator: std.mem.Allocator) Self {
            const entries = std.ArrayList(?Entry).init(allocator);
            const free_list = std.ArrayList(Id).init(allocator);

            return .{
                .allocator = allocator,
                .entries = entries,
                .free_list = free_list,
            };
        }

        // Does not handle value deinitialization
        // Use public implementation to handle that.
        pub fn deinit(self: Self) void {
            self.entries.deinit();
            self.free_list.deinit();
        }

        pub fn add(self: *Self, value: T) !Id {
            if (self.free_list.items.len > 0) {
                var id = self.free_list.pop();
                id.generation += 1;

                self.entries.items[id.index] = .{
                    .value = value,
                    .generation = id.generation,
                    .version = 0,
                };

                return id;
            }

            const index = self.entries.items.len;

            try self.entries.append(.{
                .value = value,
                .generation = 0,
                .version = 0,
            });

            return .{
                .index = index,
                .generation = 0,
            };
        }

        pub fn contains(self: Self, id: Id) bool {
            if (id.index >= self.entries.items.len) return false;
            const entry = self.entries.items[id.index] orelse return false;
            return entry.generation == id.generation;
        }

        pub fn getEntry(self: Self, id: Id) ?*Entry {
            if (id.index >= self.entries.items.len) return null;
            return &self.entries.items[id.index].?;
        }
    };
}

fn EntryType(comptime T: type) type {
    return struct {
        value: T,
        generation: u32,
        version: u32,
    };
}

pub fn IndexedMap(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Id = IdType;
        pub const Entry = EntryType(T);

        map: InternalMap(Id, Entry, T),

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .map = InternalMap(Id, Entry, T).init(allocator),
            };
        }

        pub fn deinit(self: Self) void {
            if (@hasDecl(T, "deinit")) {
                for (self.map.entries.items) |optional_entry| {
                    if (optional_entry) |entry| {
                        entry.value.deinit();
                    }
                }
            }

            self.map.deinit();
        }

        pub fn add(self: *Self, value: T) !Id {
            return self.map.add(value);
        }

        pub fn get(self: Self, id: Id) ?T {
            const entry = self.map.getEntry(id) orelse return null;
            return entry.value;
        }

        pub fn getPtr(self: *Self, id: Id) ?*T {
            const entry = self.map.getEntry(id) orelse return null;

            entry.version +%= 1;
            return &entry.value;
        }
    };
}

pub const OpagueIndexedMap = struct {
    const Self = @This();
    pub const Id = IdType;
    pub const Entry = EntryType(OpagueWrapper);

    map: InternalMap(Id, Entry, OpagueWrapper),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .map = InternalMap(Id, Entry, OpagueWrapper).init(allocator),
        };
    }

    pub fn deinit(self: Self) void {
        for (self.map.entries.items) |optional_entry| {
            if (optional_entry) |entry| {
                entry.value.deinit(self.map.allocator);
            }
        }

        self.map.deinit();
    }

    pub fn add(self: *Self, value: anytype) !Id {
        return self.map.add(try OpagueWrapper.init(self.map.allocator, value));
    }

    pub fn getOpague(self: Self, id: Id) OpagueWrapper {
        const entry = self.map.getEntry(id) orelse return null;
        return entry.value;
    }

    pub fn get(self: Self, comptime T: type, id: Id) ?T {
        const entry = self.map.getEntry(id) orelse return null;
        return entry.value.cast(T);
    }

    pub fn getPtr(self: *Self, comptime T: type, id: Id) ?*T {
        const entry = self.map.getEntry(id) orelse return null;
        entry.version +%= 1;
        return entry.value.castPtr(T);
    }

    // Sets inner ptr of opague wrapper
    pub fn set(self: *Self, id: Id, value: anytype) void {
        if (self.getPtr(@TypeOf(value), id)) |ptr| {
            ptr.* = value;
        }
    }
};
