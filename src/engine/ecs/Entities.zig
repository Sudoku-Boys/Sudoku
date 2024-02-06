const std = @import("std");
const storage = @import("storage.zig");
const Entity = @import("Entity.zig");
const EntityAllocator = @import("EntityAllocator.zig");

const Entities = @This();

pub const StorageKind = enum {
    Dense,
    Sparse,

    pub fn of(comptime T: type) StorageKind {
        switch (@typeInfo(T)) {
            .Struct => {},
            .Enum => {},
            .Union => {},
            .Opaque => {},
            else => return .Sparse,
        }

        if (!@hasDecl(T, "STORAGE")) {
            return .Sparse;
        }

        return @field(T, "STORAGE");
    }
};

allocator: EntityAllocator,
entities: std.ArrayList(u32),

dense: storage.Storage(storage.Dense),
sparse: storage.Storage(storage.Sparse),

pub fn init(allocator: std.mem.Allocator) Entities {
    return .{
        .allocator = EntityAllocator.init(allocator),
        .entities = std.ArrayList(u32).init(allocator),

        .dense = storage.Storage(storage.Dense).init(allocator),
        .sparse = storage.Storage(storage.Sparse).init(allocator),
    };
}

pub fn deinit(self: *Entities) void {
    self.entities.deinit();

    self.dense.deinit();
    self.sparse.deinit();
}

pub fn alloc(self: *Entities) !Entity {
    const entity = try self.allocator.alloc();

    if (self.entities.items.len <= entity.index) {
        const old_len = self.entities.items.len;
        const new_len = entity.index + 1;

        try self.entities.resize(new_len);

        @memset(self.entities.items[old_len..new_len], Entity.NULL_GEN);
    }

    self.entities.items[entity.index] = entity.generation;

    return entity;
}

pub fn free(self: *Entities, entity: Entity) !void {
    self.entities.items[entity.index] = Entity.NULL_GEN;

    self.dense.removeEntity(entity);
    self.sparse.removeEntity(entity);

    try self.allocator.free(entity);
}

pub fn contains(self: *const Entities, entity: Entity) bool {
    if (entity.index >= self.entities.items.len) {
        return false;
    }

    return self.entities.items[entity.index] == entity.generation;
}

pub const Iterator = struct {
    index: u32,
    generations: []const u32,

    pub fn next(self: *Iterator) ?Entity {
        if (self.index >= self.generations.len) return null;

        const generation = self.generations[self.index];
        if (generation == Entity.NULL_GEN) return null;

        const entity = .{
            .index = self.index,
            .generation = generation,
        };

        self.index += 1;
        return entity;
    }
};

pub fn iterator(self: *const Entities) Iterator {
    return .{
        .index = 0,
        .generations = self.entities.items,
    };
}

pub fn containsComponent(self: *const Entities, comptime T: type, entity: Entity) bool {
    switch (StorageKind.of(T)) {
        .Dense => return self.dense.contains(T, entity),
        .Sparse => return self.sparse.contains(T, entity),
    }
}

pub fn addComponent(self: *Entities, entity: Entity, value: anytype) !void {
    const T = @TypeOf(value);

    switch (StorageKind.of(T)) {
        .Dense => try self.dense.add(T, entity, value),
        .Sparse => try self.sparse.add(T, entity, value),
    }
}

pub fn getComponent(self: *const Entities, comptime T: type, entity: Entity) ?T {
    switch (StorageKind.of(T)) {
        .Dense => return self.dense.get(T, entity),
        .Sparse => return self.sparse.get(T, entity),
    }
}

pub fn getComponentPtr(self: *const Entities, comptime T: type, entity: Entity) ?*T {
    switch (StorageKind.of(T)) {
        .Dense => return self.dense.getPtr(T, entity),
        .Sparse => return self.sparse.getPtr(T, entity),
    }
}

pub fn removeComponent(self: *const Entities, entity: Entity, comptime T: type) !void {
    switch (StorageKind.of(T)) {
        .Dense => try self.dense.remove(T, entity),
        .Sparse => try self.sparse.remove(T, entity),
    }
}
