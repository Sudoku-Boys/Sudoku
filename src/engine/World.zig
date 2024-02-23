const std = @import("std");

const Entities = @import("Entities.zig");
const Entity = @import("Entity.zig");
const EntityRef = @import("EntityRef.zig");
const Resources = @import("Resources.zig");

const q = @import("query.zig");

const World = @This();

/// A general purpose allocator for the world.
allocator: std.mem.Allocator,

/// The entities in the world.
entities: Entities,

/// The resources in the world.
resources: Resources,

pub fn init(allocator: std.mem.Allocator) World {
    return .{
        .allocator = allocator,
        .entities = Entities.init(allocator),
        .resources = Resources.init(allocator),
    };
}

pub fn deinit(self: *World) void {
    self.entities.deinit();
    self.resources.deinit();
}

pub fn createEntity(self: *World) !EntityRef {
    const e = try self.entities.createEntity();
    return EntityRef.init(&self.entities, e);
}

pub fn destroyEntity(self: *World, e: Entity) !void {
    try self.entities.destroyEntity(e);
}

pub fn containsEntity(self: *World, e: Entity) bool {
    return self.entities.containsEntity(e);
}

pub fn getEntity(self: *World, e: Entity) ?EntityRef {
    if (!self.containsEntity(e)) return null;
    return EntityRef.init(&self.entities, e);
}

pub fn entity(self: *World, e: Entity) EntityRef {
    std.debug.assert(self.containsEntity(e));
    return EntityRef.init(&self.entities, e);
}

pub fn entityIterator(self: World) Entities.EntityIterator {
    return self.entities.entityIterator();
}

pub const EntityRefIterator = struct {
    entities: *Entities,
    it: Entities.EntityIterator,

    pub fn next(self: *EntityRefIterator) ?EntityRef {
        const e = self.it.next() orelse return null;
        return EntityRef.init(self.entities, e);
    }
};

pub fn entityRefIterator(self: *World) EntityRefIterator {
    return .{
        .entities = &self.entities,
        .it = self.entityIterator(),
    };
}

/// Create a query for the given query type `Q`, with the given query state `state`.
///
/// `QueryState` is created by `Query(Q).initState`. Note that this can be quite expensive,
/// reusing query state is recommended.
pub fn query(
    self: *World,
    comptime Q: type,
    state: q.QueryState(Q),
) q.Query(Q) {
    return .{
        .world = self,
        .state = state,
    };
}

/// Create a query for the given query type `Q`, initializing the query state.
///
/// This should only be used when the query state cannot be reused.
pub fn queryOnce(self: *World, comptime Q: type) !q.Query(Q) {
    const state = try q.Query(Q).initState(self);
    return self.query(Q, state);
}

pub fn containsResource(self: *World, comptime T: type) bool {
    return self.resources.contains(T);
}

pub fn addResource(self: *World, res: anytype) !void {
    try self.resources.add(res);
}

pub fn getResource(self: *World, comptime T: type) ?*T {
    return self.resources.get(T);
}

pub fn resource(self: *World, comptime T: type) T {
    const ptr = self.getResource(T) orelse unreachable;
    return ptr.*;
}
