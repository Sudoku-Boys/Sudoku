const std = @import("std");
const Entity = @import("Entity.zig");
const Entities = @import("Entities.zig");
const Resources = @import("Resources.zig");

const World = @This();

entities: Entities,
resources: Resources,

pub fn init(allocator: std.mem.Allocator) World {
    return .{
        .entities = Entities.init(allocator),
        .resources = Resources.init(allocator),
    };
}

pub fn deinit(self: *World) void {
    self.entities.deinit();
    self.resources.deinit();
}

pub fn allocEntity(self: *World) !Entity {
    return try self.entities.alloc();
}

pub fn freeEntity(self: *World, entity: Entity) !void {
    try self.entities.free(entity);
}

pub fn containsEntity(self: *const World, entity: Entity) bool {
    return self.entities.contains(entity);
}

pub fn containsComponent(self: *const World, comptime T: type, entity: Entity) bool {
    return self.entities.containsComponent(T, entity);
}

pub fn addComponent(self: *World, entity: Entity, value: anytype) !void {
    try self.entities.addComponent(entity, value);
}

pub fn getComponent(self: *const World, comptime T: type, entity: Entity) ?T {
    return self.entities.getComponent(T, entity);
}

pub fn getComponentPtr(self: *const World, comptime T: type, entity: Entity) ?*T {
    return self.entities.getComponentPtr(T, entity);
}

pub fn removeComponent(self: *const World, entity: Entity, comptime T: type) void {
    self.entities.removeComponent(entity, T);
}

pub fn containsResource(self: *const World, comptime T: type) bool {
    return self.resources.contains(T);
}

pub fn addResource(self: *World, value: anytype) !void {
    try self.resources.add(value);
}

pub fn getResource(self: *const World, comptime T: type) ?T {
    return self.resources.get(T);
}

pub fn getResourcePtr(self: *const World, comptime T: type) ?*T {
    return self.resources.getPtr(T);
}

pub fn removeResource(self: *World, comptime T: type) ?T {
    return self.resources.remove(T);
}
