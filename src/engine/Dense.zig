const std = @import("std");

const Component = @import("Component.zig");
const Entity = @import("Entity.zig");

const Dense = @This();

const Entry = struct {
    index: usize,
    generation: u32,

    pub const NULL: Entry = .{
        .index = 0,
        .generation = Entity.MAX_GENERATIONS,
    };

    pub fn isNull(self: Entry) bool {
        return self.generation == Entity.MAX_GENERATIONS;
    }
};

// NOTE: only the deinit function is used, but taking the whole vtable
// doesn't make a difference
vtable: *const Component.VTable,
size: usize,

entries: std.ArrayListUnmanaged(Entry),
data: std.ArrayListAlignedUnmanaged(u8, 16),

free_list: std.ArrayListUnmanaged(usize),

pub fn init(comptime T: type) Dense {
    return .{
        .vtable = Component.VTable.of(T),
        .size = @sizeOf(T),
        .entries = .{},
        .data = .{},
        .free_list = .{},
    };
}

pub fn deinit(self: *Dense, allocator: std.mem.Allocator) void {
    if (self.vtable.deinit) |vtable_deinit| {
        for (self.entries.items) |entry| {
            if (entry.isNull()) continue;

            const data = &self.data.items[entry.index];
            vtable_deinit(data);
        }
    }

    self.entries.deinit(allocator);
    self.data.deinit(allocator);

    self.free_list.deinit(allocator);
}

pub fn contains(
    self: Dense,
    entity: Entity,
) bool {
    if (self.entries.items.len <= entity.index) return false;

    const entry = self.entries.items[entity.index];
    return entry.generation == entity.generation;
}

fn alloc(self: *Dense, allocator: std.mem.Allocator, comptime T: type) !usize {
    if (self.free_list.items.len > 0) {
        return self.free_list.pop();
    }

    const index = self.data.items.len;
    try self.data.appendNTimes(allocator, 0, @sizeOf(T));

    return index;
}

pub fn put(
    self: *Dense,
    allocator: std.mem.Allocator,
    entity: Entity,
    component: anytype,
) !void {
    if (self.contains(entity)) {
        try self.destroy(allocator, entity);
    }

    if (self.entries.items.len <= entity.index) {
        const new_len = entity.index + 1;
        const delta = new_len - self.entries.items.len;
        try self.entries.appendNTimes(allocator, Entry.NULL, delta);
    }

    const entry = &self.entries.items[entity.index];
    entry.index = try self.alloc(allocator, @TypeOf(component));
    entry.generation = entity.generation;

    const data = self.data.items[entry.index .. entry.index + self.size];
    @memcpy(data, std.mem.asBytes(&component));
}

pub fn get(
    self: *Dense,
    entity: Entity,
    comptime T: type,
) ?*T {
    if (!self.contains(entity)) return null;

    const entry = &self.entries.items[entity.index];
    const data = &self.data.items[entry.index];

    return @ptrCast(@alignCast(data));
}

pub fn destroy(
    self: *Dense,
    allocator: std.mem.Allocator,
    entity: Entity,
) !void {
    if (!self.contains(entity)) return;

    const entry = &self.entries.items[entity.index];
    const data = &self.data.items[entry.index];

    if (self.vtable.deinit) |vtable_deinit| {
        vtable_deinit(data);
    }

    entry.generation = Entity.MAX_GENERATIONS;

    try self.free_list.append(allocator, entity.index);
}
