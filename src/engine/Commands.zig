//!

const std = @import("std");

const Entity = @import("Entity.zig");
const World = @import("World.zig");

const Commands = @This();

pub fn AddComponent(comptime T: type) type {
    return struct {
        const Self = @This();

        entity: Entity,
        component: T,

        fn apply(self: *Self, world: *World) !void {
            if (world.getEntity(self.entity)) |entity| {
                try entity.addComponent(self.component);
            } else {
                std.log.warn("Entity not found, {}", .{self.entity});
            }
        }
    };
}

pub const Spawn = struct {
    entity: Entity,

    fn apply(self: *Spawn, world: *World) !void {
        try world.entities.addEntity(self.entity);
    }
};

pub const Despawn = struct {
    entity: Entity,

    fn apply(self: *Despawn, world: *World) !void {
        try world.despawn(self.entity);
    }
};

pub const SetParent = struct {
    child: Entity,
    parent: Entity,

    fn apply(self: *SetParent, world: *World) !void {
        try world.setParent(self.child, self.parent);
    }
};

pub const SystemParamState = struct {
    allocator: std.mem.Allocator,
    queue: std.ArrayListUnmanaged(Command),
};

world: *World,
state: *SystemParamState,

pub fn append(self: *const Commands, command: anytype) !void {
    const cmd = try Command.init(command, self.state.allocator);
    try self.state.queue.append(self.state.allocator, cmd);
}

pub fn spawn(self: *const Commands) !EntityCommands {
    const entity = self.world.entities.allocEntity();

    const cmd = Spawn{
        .entity = entity,
    };

    try self.append(cmd);

    return .{
        .entity = entity,
        .commands = self,
    };
}

pub fn despawn(self: *const Commands, entity: Entity) !void {
    const cmd = Despawn{
        .entity = entity,
    };

    try self.append(cmd);
}

pub fn addComponent(self: *const Commands, entity: Entity, component: anytype) !void {
    const T = @TypeOf(component);
    const cmd = AddComponent(T){
        .entity = entity,
        .component = component,
    };

    try self.append(cmd);
}

pub fn setParent(self: *const Commands, child: Entity, parent: Entity) !void {
    const cmd = SetParent{
        .child = child,
        .parent = parent,
    };

    try self.append(cmd);
}

pub fn systemParamInit(world: *World) !SystemParamState {
    return .{
        .allocator = world.allocator,
        .queue = .{},
    };
}

pub fn systemParamFetch(world: *World, state: *SystemParamState) !Commands {
    return .{
        .world = world,
        .state = state,
    };
}

pub fn systemParamApply(world: *World, state: *SystemParamState) !void {
    for (state.queue.items) |*command| {
        try command.apply(world, state.allocator);
    }

    state.queue.clearRetainingCapacity();
}

pub fn systemParamDeinit(state: *SystemParamState) void {
    state.queue.deinit(state.allocator);
}

pub const EntityCommands = struct {
    entity: Entity,
    commands: *const Commands,

    pub fn entity(self: *const EntityCommands) Entity {
        return self.entity;
    }

    pub fn addComponent(self: *const EntityCommands, component: anytype) !void {
        try self.commands.addComponent(self.entity, component);
    }

    pub fn despawn(self: *const EntityCommands) !void {
        try self.commands.despawn(self.entity);
    }

    pub fn spawnChild(self: *const EntityCommands) !EntityCommands {
        const child = self.commands.spawn();
        try self.commands.setParent(child.entity, self.entity);
        return child;
    }
};

const Command = struct {
    data: *u8,
    apply_dyn: *const fn (*u8, *World, std.mem.Allocator) anyerror!void,

    fn init(
        command: anytype,
        allocator: std.mem.Allocator,
    ) !Command {
        const T = @TypeOf(command);

        const Closure = struct {
            fn apply(
                data: *u8,
                world: *World,
                alloc: std.mem.Allocator,
            ) anyerror!void {
                const command_ptr: *T = @ptrCast(@alignCast(data));
                try command_ptr.apply(world);

                if (@hasDecl(T, "deinit")) {
                    command_ptr.deinit();
                }

                if (@sizeOf(T) > 0) {
                    alloc.destroy(command_ptr);
                }
            }
        };

        var data: *T = undefined;

        if (@sizeOf(T) > 0) {
            data = try allocator.create(T);
            data.* = command;
        }

        return .{
            .data = @ptrCast(@alignCast(data)),
            .apply_dyn = Closure.apply,
        };
    }

    fn apply(
        self: *Command,
        world: *World,
        allocator: std.mem.Allocator,
    ) !void {
        try self.apply_dyn(self.data, world, allocator);
    }
};
