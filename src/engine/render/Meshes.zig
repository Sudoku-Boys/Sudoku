const std = @import("std");

const Mesh = @import("Mesh.zig");

const Meshes = @This();

pub const Id = struct {
    index: usize,
    generation: u32,
};

pub const Entry = struct {
    mesh: Mesh,
    generation: u32,
    version: u32,
};

allocator: std.mem.Allocator,
entries: std.ArrayList(?Entry),
free_list: std.ArrayList(Id),

pub fn init(allocator: std.mem.Allocator) Meshes {
    const entries = std.ArrayList(?Entry).init(allocator);
    const free_list = std.ArrayList(Id).init(allocator);

    return .{
        .allocator = allocator,
        .entries = entries,
        .free_list = free_list,
    };
}

pub fn deinit(self: Meshes) void {
    for (self.entries.items) |optional_entry| {
        if (optional_entry) |entry| {
            entry.mesh.deinit();
        }
    }

    self.entries.deinit();
    self.free_list.deinit();
}

pub fn add(self: *Meshes, mesh: Mesh) !Id {
    if (self.free_list.items.len > 0) {
        var id = self.free_list.pop();
        id.generation += 1;

        self.entries.items[id.index] = .{
            .mesh = mesh,
            .generation = id.generation,
            .version = 0,
        };

        return id;
    }

    const index = self.entries.items.len;
    try self.entries.append(.{
        .mesh = mesh,
        .generation = 0,
        .version = 0,
    });

    return .{
        .index = index,
        .generation = 0,
    };
}

pub fn contains(self: Meshes, id: Id) bool {
    if (id.index >= self.entries.items.len) return false;
    const entry = self.entries.items[id.index] orelse return false;
    return entry.generation == id.generation;
}

pub fn getEntry(self: Meshes, id: Id) ?*Entry {
    if (id.index >= self.entries.items.len) return null;
    return &self.entries.items[id.index].?;
}

pub fn get(self: Meshes, id: Id) ?Mesh {
    const entry = self.getEntry(id) orelse return null;
    return entry.mesh;
}

pub fn getPtr(self: *Meshes, id: Id) ?*Mesh {
    const entry = self.getEntry(id) orelse return null;

    entry.version +%= 1;
    return &entry.mesh;
}
