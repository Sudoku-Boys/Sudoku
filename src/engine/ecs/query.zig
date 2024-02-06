const std = @import("std");
const Entity = @import("Entity.zig");
const Entities = @import("Entities.zig");
const system = @import("system.zig");
const system_param = @import("system_param.zig");
const World = @import("World.zig");

const EntityQueryItem = struct {
    fn contains(world: *const World, entity: Entity) bool {
        return world.containsEntity(entity);
    }

    fn get(world: *const World, entity: Entity) ?Entity {
        return if (contains(world, entity)) entity else null;
    }
};

fn queryItem(comptime T: type) type {
    if (T == Entity) return EntityQueryItem;

    const Pointee = system_param.itemPointee(T);

    const access_kind = if (Pointee != null) .Write else .Read;
    const Component = Pointee orelse T;

    return struct {
        const Self = @This();

        const ACCESS = system.Access.init(Component, access_kind, .Component);

        fn contains(world: *const World, entity: Entity) bool {
            if (Pointee) |P| {
                return world.containsComponent(P, entity);
            } else {
                return world.containsComponent(T, entity);
            }
        }

        fn get(world: *const World, entity: Entity) ?T {
            if (Pointee) |P| {
                return world.getComponentPtr(P, entity);
            } else {
                return world.getComponent(T, entity);
            }
        }
    };
}

pub fn Query(comptime Q: type, comptime F: anytype) type {
    if (@typeInfo(Q) != .Struct) @compileError("Query must be a struct");
    if (@typeInfo(@TypeOf(F)) != .Struct) @compileError("Filter must be a struct");

    const query_info = @typeInfo(Q).Struct;
    const filter_info = @typeInfo(@TypeOf(F)).Struct;

    comptime var access: []const system.Access = &.{};

    for (query_info.fields) |field| {
        const Item = queryItem(field.type);

        if (!@hasDecl(Item, "ACCESS")) continue;

        if (!Item.ACCESS.isSetCompatible(access)) {
            @compileError("Query invalid");
        }

        access = access ++ .{Item.ACCESS};
    }

    return struct {
        const Self = @This();

        world: *World,

        pub const ACCESS: []const system.Access = access;

        pub fn systemFetch(world: *World) !Self {
            return .{
                .world = world,
            };
        }

        pub fn contains(self: Self, entity: Entity) bool {
            inline for (query_info.fields) |field| {
                const Item = queryItem(field.type);

                if (!Item.contains(self.world, entity)) return false;
            }

            inline for (filter_info.fields) |field| {
                const Filter = @field(F, field.name);

                if (!self.world.containsComponent(Filter, entity)) return false;
            }

            return true;
        }

        pub fn get(self: Self, entity: Entity) ?Q {
            var query: Q = undefined;

            inline for (query_info.fields) |field| {
                const Item = queryItem(field.type);

                if (Item.get(self.world, entity)) |item| {
                    @field(query, field.name) = item;
                } else {
                    return null;
                }
            }

            inline for (filter_info.fields) |field| {
                const Filter = @field(F, field.name);

                if (!self.world.containsComponent(Filter, entity)) return null;
            }

            return query;
        }

        pub const Iterator = struct {
            entity: Entities.Iterator,
            query: Self,

            pub fn next(self: *Iterator) ?Q {
                while (self.entity.next()) |entity| {
                    return self.query.get(entity) orelse continue;
                }

                return null;
            }
        };

        pub fn iterator(self: Self) Self.Iterator {
            return .{
                .entity = self.world.entities.iterator(),
                .query = self,
            };
        }
    };
}
