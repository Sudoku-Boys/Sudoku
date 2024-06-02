const std = @import("std");

const Entities = @import("Entities.zig");
const Entity = @import("Entity.zig");
const EntityRef = @import("EntityRef.zig");
const Resources = @import("Resources.zig");

const q = @import("query.zig");
const h = @import("hirachy.zig");

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

pub fn spawn(self: *World) !EntityRef {
    const e = self.entities.allocEntity();
    try self.entities.addEntity(e);
    return EntityRef.init(&self.entities, e);
}

pub fn despawn(self: *World, e: Entity) !void {
    if (self.entity(e).getComponent(h.Children)) |c| {
        for (c.children.items) |child| {
            try self.despawn(child);
        }
    }

    if (self.entity(e).getComponent(h.Parent)) |p| {
        if (self.entity(p.entity).getComponent(h.Children)) |c| {
            c.remove(e);
        }
    }

    try self.entities.removeEntity(e);
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
    return self.queryFilter(Q, .{}, state);
}

pub fn queryFilter(
    self: *World,
    comptime Q: type,
    comptime F: anytype,
    state: q.QueryFilterState(Q, F),
) q.QueryFilter(Q, F) {
    return .{
        .world = self,
        .state = state,
    };
}

pub fn set_parent(self: *World, child: Entity, parent: Entity) !void {
    if (!self.containsEntity(child) or !self.containsEntity(parent)) {
        return;
    }

    if (self.entity(child).getComponent(h.Parent)) |p| {
        const prev = p.entity;
        p.entity = parent;

        const children = self.entity(parent).getComponent(h.Children).?;
        children.remove(prev);
    } else {
        try self.entity(child).addComponent(h.Parent{ .entity = parent });
    }

    if (self.entity(parent).getComponent(h.Children)) |c| {
        try c.add(child);
    } else {
        var children = h.Children.init(self.allocator);
        try children.add(child);
        try self.entity(parent).addComponent(children);
    }
}

/// Create a query for the given query type `Q`, initializing the query state.
///
/// This should only be used when the query state cannot be reused.
pub fn queryOnce(self: *World, comptime Q: type) !q.Query(Q) {
    const state = try q.QueryFilter(Q).initState(self);
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

pub fn resourcePtr(self: *World, comptime T: type) *T {
    const ptr = self.getResource(T) orelse std.debug.panic("resource not found {}", .{T});
    return ptr;
}

pub fn resource(self: *World, comptime T: type) T {
    return self.resourcePtr(T).*;
}
