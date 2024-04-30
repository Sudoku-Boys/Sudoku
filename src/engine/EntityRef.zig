const Entity = @import("Entity.zig");
const Entities = @import("Entities.zig");

const EntityRef = @This();

entities: *Entities,
entity: Entity,

pub fn init(entities: *Entities, entity: Entity) EntityRef {
    return .{
        .entities = entities,
        .entity = entity,
    };
}

pub fn addComponent(self: EntityRef, value: anytype) !void {
    try self.entities.putComponent(self.entity, value);
}

pub fn component(self: EntityRef, comptime T: type) T {
    return self.entities.getComponent(self.entity, T).?.*;
}

pub fn getComponent(self: EntityRef, comptime T: type) ?*T {
    return self.entities.getComponent(self.entity, T);
}

pub fn destroyComponent(self: EntityRef, comptime T: type) !void {
    try self.entities.destroyComponent(self.entity, T);
}

pub fn destroy(self: EntityRef) !void {
    try self.entities.removeEntity(self.entity);
}
