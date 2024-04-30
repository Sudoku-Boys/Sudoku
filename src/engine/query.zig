const std = @import("std");

const Entities = @import("Entities.zig");
const Entity = @import("Entity.zig");
const World = @import("World.zig");

fn isQueryItemPointer(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Pointer => |pointer| return pointer.size == .One and !pointer.is_const,
        else => return false,
    }
}

fn QueryItemComponent(comptime T: type) type {
    if (isQueryItemPointer(T)) {
        return @typeInfo(T).Pointer.child;
    } else {
        return T;
    }
}

const EntityQueryItem = struct {
    pub const State = void;

    pub fn initState(world: *World) !State {
        _ = world;

        return {};
    }

    pub fn contains(world: *World, state: State, entity: Entity) bool {
        _ = world;
        _ = state;
        _ = entity;

        return true;
    }

    pub fn fetch(world: *World, state: State, entity: Entity) ?Entity {
        _ = world;
        _ = state;

        return entity;
    }
};

pub fn QueryItem(comptime T: type) type {
    if (T == Entity) {
        return EntityQueryItem;
    }

    const C = QueryItemComponent(T);

    return struct {
        pub const State = Entities.Storage;

        pub fn initState(world: *World) !State {
            return try world.entities.registerComponent(C);
        }

        pub fn contains(world: *World, state: State, entity: Entity) bool {
            return world.entities.containsComponentRegistered(state, entity);
        }

        pub fn fetch(world: *World, state: State, entity: Entity) ?T {
            const ptr = world.entities.getComponentRegistered(state, entity, C) orelse return null;

            if (comptime isQueryItemPointer(T)) {
                return ptr;
            }

            return ptr.*;
        }
    };
}

pub fn Query(comptime Q: type) type {
    const query_info = @typeInfo(Q);

    if (query_info != .Struct) {
        @compileError("Query must be a struct with named fields");
    }

    const query_struct = query_info.Struct;

    comptime var state_fields: []const std.builtin.Type.StructField = &.{};

    for (query_struct.fields) |field| {
        const Item = QueryItem(field.type);

        const state_field = std.builtin.Type.StructField{
            .name = field.name,
            .type = Item.State,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };

        state_fields = state_fields ++ .{state_field};
    }

    return struct {
        const Self = @This();

        /// The state of the query.
        pub const State = @Type(std.builtin.Type{
            .Struct = .{
                .layout = .auto,
                .fields = state_fields,
                .decls = &.{},
                .is_tuple = false,
            },
        });

        pub const SystemParamState = State;

        world: *World,
        state: State,

        /// Initialize the `State`, `world` **must** be the same as the `world` used to create the query
        /// or segmentation faults will be on the menu.
        pub fn initState(world: *World) !State {
            var state: State = undefined;

            inline for (query_struct.fields) |field| {
                const Item = QueryItem(field.type);
                @field(state, field.name) = try Item.initState(world);
            }

            return state;
        }

        pub fn systemParamInit(world: *World) !SystemParamState {
            return initState(world);
        }

        pub fn systemParamFetch(world: *World, state: *SystemParamState) !Self {
            return world.query(Q, state.*);
        }

        pub fn systemParamApply(world: *World, state: *SystemParamState) !void {
            _ = state;
            _ = world;
        }

        /// Check if the query contains the given `entity`.
        ///
        /// This ensuses that `fetch` will not return `null` for the given `entity`.
        pub fn contains(self: *const Self, entity: Entity) bool {
            inline for (query_struct.fields) |field| {
                const Item = QueryItem(field.type);
                const state = @field(self.state, field.name);

                if (!Item.contains(self.world, state, entity)) {
                    return false;
                }
            }

            return true;
        }

        /// Fetch the query for the given `entity`.
        pub fn fetch(self: *const Self, entity: Entity) ?Q {
            var query: Q = undefined;

            inline for (query_struct.fields) |field| {
                const Item = QueryItem(field.type);
                const state = @field(self.state, field.name);

                const item = Item.fetch(self.world, state, entity) orelse return null;

                @field(query, field.name) = item;
            }

            return query;
        }

        pub const Iterator = struct {
            query: *const Self,
            it: Entities.EntityIterator,

            pub fn next(self: *Iterator) ?Q {
                while (self.it.next()) |entity| {
                    return self.query.fetch(entity) orelse continue;
                }

                return null;
            }
        };

        /// Create an iterator over the query.
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .query = self,
                .it = self.world.entities.entityIterator(),
            };
        }
    };
}

/// Get the `State` associated with the given `Query` for type `Q`.
///
/// This is a shorthand for `Query(Q).State`.
pub fn QueryState(comptime Q: type) type {
    return Query(Q).State;
}
