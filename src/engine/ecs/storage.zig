const std = @import("std");
const dynamic = @import("dynamic.zig");
const Entity = @import("Entity.zig");

fn alignedSizeOf(comptime T: type) usize {
    if (@sizeOf(T) == 0) return 0;
    return std.mem.alignForward(usize, @sizeOf(T), @alignOf(T));
}

pub const ComponentInfo = struct {
    alignedSize: usize,
    deinit: ?*const fn (*anyopaque) void,

    pub fn of(comptime T: type) ComponentInfo {
        return .{
            .alignedSize = alignedSizeOf(T),
            .deinit = dynamic.deinitFn(T),
        };
    }
};

fn typeId(comptime T: type) std.builtin.TypeId {
    return std.meta.activeTag(@typeInfo(T));
}

fn ptrCast(comptime T: type, ptr: anytype) *T {
    return @ptrCast(@alignCast(ptr));
}

pub const Dense = struct {
    info: ComponentInfo,

    pub fn init(comptime T: type, allocator: std.mem.Allocator) Dense {
        _ = allocator;
        return .{
            .info = ComponentInfo.of(T),
        };
    }

    pub fn deinit(self: *Dense) void {
        _ = self;
    }

    pub fn contains(self: *const Dense, entity: Entity) bool {
        _ = entity;
        _ = self;

        return false;
    }

    pub fn add(self: *Dense, comptime T: type, entity: Entity, component: T) !void {
        _ = self;
        _ = entity;
        _ = component;
    }

    pub fn get(self: *const Dense, comptime T: type, entity: Entity) ?T {
        _ = entity;
        _ = self;

        return null;
    }

    pub fn getPtr(self: *Dense, comptime T: type, entity: Entity) ?*T {
        _ = entity;
        _ = self;

        return null;
    }

    pub fn remove(self: *Dense, comptime T: type, entity: Entity) ?T {
        _ = entity;
        _ = self;

        return null;
    }

    pub fn removeEntity(self: *Dense, entity: Entity) void {
        _ = entity;
        _ = self;
    }
};

pub const Sparse = struct {
    info: ComponentInfo,

    entities: []u32,
    data: []u8,

    allocator: std.mem.Allocator,

    pub fn init(comptime T: type, allocator: std.mem.Allocator) Sparse {
        return .{
            .info = ComponentInfo.of(T),

            .entities = &.{},
            .data = &.{},

            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Sparse) void {
        if (self.info.deinit) |deinitComponent| {
            for (self.entities, 0..) |gen, i| {
                if (gen == Entity.NULL_GEN) continue;

                const data = self.getDataPtr(@intCast(i));
                deinitComponent(data);
            }
        }

        if (self.capacity() > 0) {
            self.allocator.free(self.entities);
            self.allocator.free(self.data);
        }
    }

    pub fn capacity(self: Sparse) usize {
        return self.entities.len;
    }

    pub fn contains(self: *const Sparse, entity: Entity) bool {
        if (entity.index >= self.capacity()) {
            return false;
        }

        return self.entities[entity.index] == entity.generation;
    }

    fn grow(self: *Sparse, comptime T: type) !void {
        if (self.capacity() == 0) {
            const new_cap = 16;

            self.entities = try self.allocator.alloc(u32, new_cap);

            @memset(self.entities, Entity.NULL_GEN);

            if (@alignOf(T) > 0) {
                self.data = std.mem.sliceAsBytes(try self.allocator.alloc(T, new_cap));
            }
        } else {
            const old_cap = self.capacity();
            const new_cap = self.capacity() * 2;

            self.entities = try self.allocator.realloc(self.entities, new_cap);

            @memset(self.entities[old_cap..new_cap], Entity.NULL_GEN);

            if (@alignOf(T) > 0) {
                const data = std.mem.bytesAsSlice(T, self.data);
                self.data = std.mem.sliceAsBytes(try self.allocator.realloc(data, new_cap));
            }
        }
    }

    fn dataOffset(self: *const Sparse, index: u32) usize {
        return index * self.info.alignedSize;
    }

    fn getDataPtr(self: *const Sparse, index: u32) *u8 {
        return @ptrCast(self.data.ptr + dataOffset(self, index));
    }

    pub fn add(self: *Sparse, comptime T: type, entity: Entity, component: T) !void {
        while (entity.index >= self.capacity()) try self.grow(T);

        const data = self.getDataPtr(entity.index);

        if (self.entities[entity.index] == 0) {
            if (self.info.deinit) |deinitComponent| {
                deinitComponent(data);
            }
        }

        self.entities[entity.index] = entity.generation;

        ptrCast(T, data).* = component;
    }

    pub fn get(self: *const Sparse, comptime T: type, entity: Entity) ?T {
        if (self.getPtr(T, entity)) |ptr| {
            return ptr.*;
        }

        return null;
    }

    pub fn getPtr(self: *const Sparse, comptime T: type, entity: Entity) ?*T {
        if (!self.contains(entity)) return null;

        const data = self.getDataPtr(entity.index);
        return ptrCast(T, data);
    }

    pub fn remove(self: *Sparse, comptime T: type, entity: Entity) ?T {
        if (self.get(T, entity)) |component| {
            self.entities[entity.index] = Entity.NULL_GEN;
            return component;
        }

        return null;
    }

    pub fn removeEntity(self: *Sparse, entity: Entity) void {
        if (!self.contains(entity)) return;

        if (self.info.deinit) |deinitComponent| {
            deinitComponent(self.getDataPtr(entity.index));
        }

        self.entities[entity.index] = Entity.NULL_GEN;
    }
};

pub fn Storage(comptime S: type) type {
    return struct {
        storages: std.AutoHashMap(std.builtin.TypeId, S),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .storages = std.AutoHashMap(std.builtin.TypeId, S).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.storages.valueIterator();
            while (it.next()) |storage| {
                storage.deinit();
            }

            self.storages.deinit();
        }

        pub fn contains(self: *const Self, comptime T: type, entity: Entity) bool {
            if (self.storages.get(typeId(T))) |storage| {
                return storage.contains(entity);
            }

            return false;
        }

        pub fn add(self: *Self, comptime T: type, entity: Entity, component: T) !void {
            if (!self.storages.contains(typeId(T))) {
                try self.storages.put(typeId(T), S.init(T, self.allocator));
            }

            try self.storages.getPtr(typeId(T)).?.add(T, entity, component);
        }

        pub fn get(self: *const Self, comptime T: type, entity: Entity) ?T {
            if (self.storages.getPtr(typeId(T))) |storage| {
                return storage.get(T, entity);
            }

            return null;
        }

        pub fn getPtr(self: *const Self, comptime T: type, entity: Entity) ?*T {
            if (self.storages.getPtr(typeId(T))) |storage| {
                return storage.getPtr(T, entity);
            }

            return null;
        }

        pub fn remove(self: *const Self, comptime T: type, entity: Entity) ?T {
            if (self.storages.getPtr(typeId(T))) |storage| {
                return storage.remove(T, entity);
            }

            return null;
        }

        pub fn removeEntity(self: *const Self, entity: Entity) void {
            var it = self.storages.valueIterator();
            while (it.next()) |storage| {
                storage.removeEntity(entity);
            }
        }
    };
}
