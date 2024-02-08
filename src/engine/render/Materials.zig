const std = @import("std");

const OpaqueMaterial = @import("OpaqueMaterial.zig");

const Materials = @This();

pub const Id = struct {
    index: usize,
    generation: u32,
};

pub const Entry = struct {
    material: OpaqueMaterial,
    generation: u32,
    version: u32,
};

allocator: std.mem.Allocator,
entries: std.ArrayList(?Entry),
free_list: std.ArrayList(Id),

pub fn init(allocator: std.mem.Allocator) Materials {
    const entries = std.ArrayList(?Entry).init(allocator);
    const free_list = std.ArrayList(Id).init(allocator);

    return .{
        .allocator = allocator,
        .entries = entries,
        .free_list = free_list,
    };
}

pub fn deinit(self: Materials) void {
    for (self.entries.items) |optional_entry| {
        if (optional_entry) |entry| {
            entry.material.deinit(self.allocator);
        }
    }

    self.entries.deinit();
    self.free_list.deinit();
}

pub fn add(self: *Materials, material: anytype) !Id {
    const opaque_material = try OpaqueMaterial.init(self.allocator, material);

    if (self.free_list.items.len > 0) {
        var id = self.free_list.pop();
        id.generation += 1;

        self.entries.items[id.index] = .{
            .material = opaque_material,
            .generation = id.generation,
            .version = 0,
        };

        return id;
    }

    const index = self.entries.items.len;
    try self.entries.append(.{
        .material = opaque_material,
        .generation = 0,
        .version = 0,
    });

    return .{
        .index = index,
        .generation = 0,
    };
}

pub fn contains(self: Materials, id: Id) bool {
    if (id.index >= self.entries.items.len) return false;
    const entry = self.entries.items[id.index] orelse return false;
    return entry.generation == id.generation;
}

pub fn getEntry(self: Materials, id: Id) ?*Entry {
    if (!self.contains(id)) return null;
    return &self.entries.items[id.index].?;
}

pub fn getOpaque(self: Materials, id: Id) ?OpaqueMaterial {
    const entry = self.getEntry(id) orelse return null;
    return entry.material;
}

pub fn get(self: Materials, comptime T: type, id: Id) ?T {
    const opaque_material = self.getOpaque(id) orelse return null;
    return opaque_material.cast(T);
}

pub fn getPtr(self: *Materials, comptime T: type, id: Id) ?*T {
    const entry = self.getEntry(id) orelse return null;

    entry.version +%= 1;
    return entry.material.castPtr(T);
}

pub fn set(self: *Materials, id: Id, material: anytype) void {
    const T = @TypeOf(material);

    if (self.getPtr(T, id)) |ptr| {
        ptr.* = material;
    }
}
