const std = @import("std");

const Commands = @import("Commands.zig");
const Entity = @import("Entity.zig");
const Game = @import("Game.zig");
const Transform = @import("Transform.zig");
const GlobalTransform = @import("GlobalTransform.zig");

const q = @import("query.zig");

pub const HirachyPhase = enum {
    Transform,
};

pub const Parent = struct {
    entity: Entity,
};

pub const Children = struct {
    children: std.ArrayList(Entity),

    pub fn init(allocator: std.mem.Allocator) Children {
        return .{
            .children = std.ArrayList(Entity).init(allocator),
        };
    }

    pub fn deinit(self: Children) void {
        self.children.deinit();
    }

    pub fn contains(self: Children, entity: Entity) bool {
        for (self.children.items) |child| {
            if (child.eql(entity)) return true;
        }

        return false;
    }

    pub fn add(self: *Children, entity: Entity) !void {
        if (self.contains(entity)) return;

        try self.children.append(entity);
    }

    pub fn remove(self: *Children, entity: Entity) void {
        for (self.children.items, 0..) |child, i| {
            if (child.eql(entity)) {
                _ = self.children.swapRemove(i);

                return;
            }
        }
    }
};

const TransformQuery = q.Query(struct {
    transform: Transform,
    global_transform: *GlobalTransform,
    parent: Parent,
});

const ChildrenQuery = q.Query(struct {
    children: Children,
});

pub fn transform_system(
    root: q.QueryFilter(
        struct {
            entity: Entity,
            children: Children,
            transform: Transform,
            global_transform: *GlobalTransform,
        },
        .{q.Without(Parent)},
    ),
    transform: TransformQuery,
    children: ChildrenQuery,
) !void {
    var it = root.iterator();
    while (it.next()) |r| {
        r.global_transform.translation = r.transform.translation;
        r.global_transform.rotation = r.transform.rotation;
        r.global_transform.scale = r.transform.scale;

        for (r.children.children.items) |child| {
            try propagate_recursive(
                child,
                r.entity,
                r.global_transform.*,
                transform,
                children,
            );
        }
    }
}

fn propagate_recursive(
    entity: Entity,
    parent: Entity,
    parent_transform: GlobalTransform,
    transform_query: TransformQuery,
    children_query: ChildrenQuery,
) !void {
    if (transform_query.fetch(entity)) |t| {
        t.global_transform.* = parent_transform.transform(t.transform);

        if (!t.parent.entity.eql(parent)) {
            std.log.warn("Entity {} has parent {} but should have {}", .{
                entity,
                t.parent.entity,
                parent,
            });
        }

        if (children_query.fetch(entity)) |c| {
            for (c.children.children.items) |child| {
                try propagate_recursive(
                    child,
                    entity,
                    t.global_transform.*,
                    transform_query,
                    children_query,
                );
            }
        }
    }
}

pub const HirachyPlugin = struct {
    pub fn buildPlugin(self: HirachyPlugin, game: *Game) !void {
        _ = self;

        const system = try game.addSystem(transform_system);
        system.name("Hirachy");
        system.after(Game.Phase.Update);
        system.before(Game.Phase.Render);
        system.label(HirachyPhase.Transform);
    }
};
