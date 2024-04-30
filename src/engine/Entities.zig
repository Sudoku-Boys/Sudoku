const std = @import("std");

const Entity = @import("Entity.zig");
const Dense = @import("Dense.zig");
const TypeId = @import("TypeId.zig");

const Entities = @This();

pub const Storage = union(enum) {
    Zst: u32,
    Dense: u32,
};

const ZstStorage = struct {
    entities: std.ArrayListUnmanaged(u32) = .{},

    fn deinit(self: *ZstStorage, allocator: std.mem.Allocator) void {
        self.entities.deinit(allocator);
    }

    fn contains(self: ZstStorage, entity: Entity) bool {
        if (self.entities.items.len <= entity.index) return false;

        const generation = self.entities.items[entity.index];
        return generation == entity.generation;
    }

    fn put(self: *ZstStorage, allocator: std.mem.Allocator, entity: Entity) !void {
        if (self.entities.items.len <= entity.index) {
            const new_len = entity.index + 1;
            const old_len = self.entities.items.len;
            const delta = new_len - old_len;

            try self.entities.appendNTimes(allocator, Entity.MAX_GENERATIONS, delta);
        }

        self.entities.items[entity.index] = entity.generation;
    }

    fn remove(self: *ZstStorage, entity: Entity) void {
        if (self.entities.items.len <= entity.index) return;
        self.entities.items[entity.index] = Entity.MAX_GENERATIONS;
    }
};

allocator: std.mem.Allocator,

entity_allocator: EntityAllocator,
entities: std.ArrayListUnmanaged(u32),

storages: std.AutoHashMapUnmanaged(TypeId, Storage),

zst: std.ArrayListUnmanaged(ZstStorage),
dense: std.ArrayListUnmanaged(Dense),

pub fn init(allocator: std.mem.Allocator) Entities {
    return .{
        .allocator = allocator,
        .entity_allocator = .{},
        .entities = .{},
        .storages = .{},
        .zst = .{},
        .dense = .{},
    };
}

pub fn deinit(self: *Entities) void {
    for (self.zst.items) |*zst| {
        zst.deinit(self.allocator);
    }

    for (self.dense.items) |*dense| {
        dense.deinit(self.allocator);
    }

    self.entity_allocator.deinit(self.allocator);
    self.entities.deinit(self.allocator);
    self.storages.deinit(self.allocator);

    self.zst.deinit(self.allocator);
    self.dense.deinit(self.allocator);
}

pub fn addEntity(self: *Entities) !Entity {
    const entity = self.entity_allocator.alloc();

    if (self.entities.items.len <= entity.index) {
        const new_len = entity.index + 1;
        const old_len = self.entities.items.len;
        const delta = new_len - old_len;

        try self.entities.appendNTimes(self.allocator, Entity.MAX_GENERATIONS, delta);
    }

    self.entities.items[entity.index] = entity.generation;

    return entity;
}

pub fn removeEntity(self: *Entities, entity: Entity) !void {
    for (self.dense.items) |*dense| {
        try dense.destroy(self.allocator, entity);
    }

    try self.entity_allocator.free(self.allocator, entity);
    self.entities.items[entity.index] = Entity.MAX_GENERATIONS;
}

pub fn containsEntity(self: *Entities, entity: Entity) bool {
    if (self.entities.items.len <= entity.index) return false;
    return self.entities.items[entity.index] == entity.generation;
}

pub const EntityIterator = struct {
    entities: []const u32,
    index: u32,

    pub fn next(self: *EntityIterator) ?Entity {
        while (self.index < self.entities.len) {
            const generation = self.entities[self.index];

            if (generation == Entity.MAX_GENERATIONS) {
                self.index += 1;
                continue;
            }

            const entity = .{
                .index = self.index,
                .generation = generation,
            };

            self.index += 1;

            return entity;
        }

        return null;
    }
};

pub fn entityIterator(self: Entities) EntityIterator {
    return .{
        .entities = self.entities.items,
        .index = 0,
    };
}

fn registerZst(self: *Entities, comptime T: type) !Storage {
    const type_id = TypeId.of(T);

    const storage = Storage{
        .Zst = @intCast(self.zst.items.len),
    };

    try self.storages.put(self.allocator, type_id, storage);

    const zst = ZstStorage{};
    try self.zst.append(self.allocator, zst);

    return storage;
}

fn registerDense(self: *Entities, comptime T: type) !Storage {
    const type_id = TypeId.of(T);

    const storage = Storage{
        .Dense = @intCast(self.dense.items.len),
    };

    try self.storages.put(self.allocator, type_id, storage);

    const dense = Dense.init(T);
    try self.dense.append(self.allocator, dense);

    return storage;
}

pub fn getStorage(self: *Entities, comptime T: type) ?Storage {
    const type_id = TypeId.of(T);
    return self.storages.get(type_id);
}

pub fn registerComponent(self: *Entities, comptime T: type) !Storage {
    const type_id = TypeId.of(T);

    if (self.storages.get(type_id)) |storage| return storage;

    if (@sizeOf(T) == 0) {
        return self.registerZst(T);
    }

    return self.registerDense(T);
}

pub fn containsComponentRegistered(
    self: *Entities,
    storage: Storage,
    entity: Entity,
) bool {
    switch (storage) {
        .Zst => |index| {
            return self.zst.items[index].contains(entity);
        },
        .Dense => |index| {
            return self.dense.items[index].contains(entity);
        },
    }
}

pub fn containsComponent(self: *Entities, entity: Entity, comptime T: type) bool {
    const storage = self.getStorage(T) orelse return false;
    return self.containsComponentRegistered(storage, entity);
}

pub fn putComponentRegistered(
    self: *const Entities,
    storage: Storage,
    entity: Entity,
    component: anytype,
) !void {
    switch (storage) {
        .Zst => |index| {
            try self.zst.items[index].put(self.allocator, entity);
        },
        .Dense => |index| {
            try self.dense.items[index].put(self.allocator, entity, component);
        },
    }
}

pub fn putComponent(self: *Entities, entity: Entity, component: anytype) !void {
    const storage = try self.registerComponent(@TypeOf(component));
    try self.putComponentRegistered(storage, entity, component);
}

pub fn getComponentRegistered(
    self: *const Entities,
    storage: Storage,
    entity: Entity,
    comptime T: type,
) ?*T {
    switch (storage) {
        .Zst => |index| {
            if (!self.zst.items[index].contains(entity)) return null;
            return undefined;
        },
        .Dense => |index| {
            return self.dense.items[index].get(entity, T);
        },
    }
}

pub fn getComponent(self: *Entities, entity: Entity, comptime T: type) ?*T {
    const storage = self.getStorage(T) orelse return null;
    return self.getComponentRegistered(storage, entity, T);
}

pub fn destroyComponentRegistered(
    self: *Entities,
    storage: Storage,
    entity: Entity,
) !void {
    switch (storage) {
        .Zst => {},
        .Dense => |index| {
            try self.dense.items[index].destroy(self.allocator, entity);
        },
    }
}

pub fn destroyComponent(self: *Entities, entity: Entity, comptime T: type) !void {
    const storage = try self.registerComponent(T);
    try self.destroyComponentRegistered(storage, entity);
}

pub const EntityAllocator = struct {
    next_index: u32 = 0,
    free_list: std.ArrayListUnmanaged(Entity) = .{},

    pub fn deinit(self: *EntityAllocator, allocator: std.mem.Allocator) void {
        self.free_list.deinit(allocator);
    }

    pub fn alloc(self: *EntityAllocator) Entity {
        if (self.free_list.items.len > 0) {
            var entity = self.free_list.pop();
            entity.generation += 1;

            std.debug.assert(entity.generation != Entity.MAX_GENERATIONS);

            return entity;
        }

        const index = self.next_index;
        self.next_index += 1;
        return Entity.init(index);
    }

    pub fn free(self: *EntityAllocator, allocator: std.mem.Allocator, entity: Entity) !void {
        try self.free_list.append(allocator, entity);
    }
};
