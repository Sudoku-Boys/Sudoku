const std = @import("std");
const Mesh = @import("Mesh.zig");

const Self = @This();

pub const Id = struct {
    index: usize,
    generation: u32,
};

pub const Entry = struct {
    value: Mesh,
    generation: u32,
    version: u32,
};

allocator: std.mem.Allocator,
entries: std.ArrayList(?Entry),
free_list: std.ArrayList(Id),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .entries = std.ArrayList(?Entry).init(allocator),
        .free_list = std.ArrayList(Id).init(allocator),
    };
}

pub fn deinit(self: Self) void {
    for (self.entries.items) |optional_entry| {
        if (optional_entry) |entry| {
            entry.value.deinit();
        }
    }

    self.entries.deinit();
    self.free_list.deinit();
}

pub fn contains(self: Self, id: Id) bool {
    if (id.index >= self.entries.items.len) {
        return false;
    }

    const entry = self.entries.items[id.index].?;
    return entry.generation == id.generation;
}

pub fn add(self: *Self, value: Mesh) !Id {
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

pub fn get(self: Self, comptime T: type, id: Id) ?T {
    if (!self.contains(id)) return null;
    return self.entries.items[id.index].?.value;
}

pub fn getPtr(self: *Self, comptime T: type, id: Id) ?*T {
    if (!self.contains(id)) return null;

    const entry = &self.entries.items[id.index].?;
    entry.version += 1;

    return &entry.value;
}
