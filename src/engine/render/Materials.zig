const std = @import("std");
const OpaqueMaterial = @import("OpaqueMaterial.zig");

const Materials = @This();

pub const Id = struct {
    index: usize,
    generation: u32,
};

pub const Entry = struct {
    value: OpaqueMaterial,
    generation: u32,
    version: u32,
};

allocator: std.mem.Allocator,
entries: std.ArrayList(?Entry),
free_list: std.ArrayList(Id),

pub fn init(allocator: std.mem.Allocator) Materials {
    return Materials{
        .allocator = allocator,
        .entries = std.ArrayList(?Entry).init(allocator),
        .free_list = std.ArrayList(Id).init(allocator),
    };
}

pub fn deinit(self: Materials) void {
    for (self.entries.items) |optional_entry| {
        if (optional_entry) |entry| {
            entry.value.deinit(self.allocator);
        }
    }

    self.entries.deinit();
    self.free_list.deinit();
}

pub fn len(self: Materials) usize {
    return self.entries.items.len;
}

pub fn contains(self: Materials, id: Id) bool {
    if (id.index >= self.entries.items.len) {
        return false;
    }

    const entry = self.entries.items[id.index].?;
    return entry.generation == id.generation;
}

pub fn add(self: *Materials, value: anytype) !Id {
    const material = try OpaqueMaterial.init(self.allocator, value);

    if (self.free_list.items.len > 0) {
        var id = self.free_list.pop();
        id.generation += 1;

        self.entries.items[id.index] = .{
            .value = material,
            .generation = id.generation,
            .version = 0,
        };

        return id;
    }

    const index = self.entries.items.len;
    try self.entries.append(.{
        .value = material,
        .generation = 0,
        .version = 0,
    });

    return .{
        .index = index,
        .generation = 0,
    };
}

pub fn getOpaque(self: Materials, id: Id) ?OpaqueMaterial {
    if (!self.contains(id)) return null;
    return self.entries.items[id.index].?.value;
}

pub fn get(self: Materials, comptime T: type, id: Id) ?T {
    const material = self.getOpaque(id) orelse return null;
    return material.cast(T);
}

pub fn getPtr(self: *Materials, comptime T: type, id: Id) ?*T {
    if (!self.contains(id)) return null;

    const entry = &self.entries.items[id.index].?;
    entry.version += 1;

    return entry.value.castPtr(T);
}

pub const EntryIterator = struct {
    entries: []?Entry,

    pub fn next(self: *EntryIterator) ?Entry {
        while (self.entries.len > 0) {
            const optional_entry = self.entries[0];
            self.entries = self.entries[1..];

            return optional_entry orelse continue;
        }

        return null;
    }
};

pub fn entryIterator(self: Materials) EntryIterator {
    return .{
        .entries = self.entries.items,
    };
}
