const std = @import("std");
const vk = @import("vulkan");

const Entity = @import("../Entity.zig");

const DrawCommand = @This();

entity: Entity,
transmissive: bool,
pipeline: vk.GraphicsPipeline,
bind_groups: []const vk.BindGroup,
vertex_buffers: []const vk.Buffer,
index_buffer: vk.Buffer,
index_count: u32,

pub fn deinit(self: DrawCommand, allocator: std.mem.Allocator) void {
    allocator.free(self.bind_groups);
    allocator.free(self.vertex_buffers);
}

pub const Queue = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayListUnmanaged(DrawCommand),

    pub fn init(allocator: std.mem.Allocator) Queue {
        return Queue{
            .allocator = allocator,
            .commands = .{},
        };
    }

    pub fn deinit(self: *Queue) void {
        for (self.commands.items) |command| {
            command.deinit(self.allocator);
        }

        self.commands.deinit(self.allocator);
    }

    pub fn push(self: *Queue, command: DrawCommand) !void {
        try self.commands.append(self.allocator, command);
    }

    pub fn clear(self: *Queue) void {
        for (self.commands.items) |command| {
            command.deinit(self.allocator);
        }

        self.commands.clearRetainingCapacity();
    }
};
