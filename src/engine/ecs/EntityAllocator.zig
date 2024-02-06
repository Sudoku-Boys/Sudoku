const std = @import("std");
const Entity = @import("Entity.zig");

const EntityAllocator = @This();

next_index: u32,
free_list: std.ArrayList(Entity),

pub fn init(allocator: std.mem.Allocator) EntityAllocator {
    return .{
        .next_index = 0,
        .free_list = std.ArrayList(Entity).init(allocator),
    };
}

pub fn deinit(self: EntityAllocator) void {
    self.free_list.deinit();
}

pub fn alloc(self: *EntityAllocator) !Entity {
    if (self.free_list.items.len > 0) {
        var entity = self.free_list.pop();
        entity.generation += 1;
        return entity;
    }

    const index = self.next_index;
    self.next_index += 1;

    return .{
        .index = index,
        .generation = 0,
    };
}

pub fn free(self: *EntityAllocator, entity: Entity) !void {
    try self.free_list.append(entity);
}

test "Alloc" {
    var allocator = EntityAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var entity = allocator.alloc();
    std.texting.expect(entity.index == 0);
    std.texting.expect(entity.generation == 0);

    entity = allocator.alloc();
    std.texting.expect(entity.index == 1);
    std.texting.expect(entity.generation == 0);
}

test "Free" {
    var allocator = EntityAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var entity = allocator.alloc();
    allocator.free(entity);

    entity = allocator.alloc();
    std.texting.expect(entity.index == 0);
    std.texting.expect(entity.generation == 1);

    entity = allocator.alloc();
    std.texting.expect(entity.index == 1);
    std.texting.expect(entity.generation == 0);
}
