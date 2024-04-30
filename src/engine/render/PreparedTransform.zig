const std = @import("std");
const vk = @import("vulkan");

const Commands = @import("../Commands.zig");
const Entity = @import("../Entity.zig");
const Query = @import("../query.zig").Query;
const Transform = @import("../Transform.zig");

const PreparedTransform = @This();

buffer: vk.Buffer,
bind_group_pool: vk.BindGroupPool,
bind_group: vk.BindGroup,

pub fn init(
    device: vk.Device,
    pipeline: Pipeline,
) !PreparedTransform {
    const buffer = try device.createBuffer(.{
        .size = @sizeOf(Uniforms),
        .usage = .{ .uniform_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer buffer.deinit();

    const bind_group_pool = try device.createBindGroupPool(.{
        .pool_sizes = &.{.{
            .type = .UniformBuffer,
            .count = 1,
        }},
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const bind_group = try bind_group_pool.alloc(pipeline.layout);

    device.updateBindGroups(.{
        .writes = &.{.{
            .dst = bind_group,
            .binding = 0,
            .resource = .{ .buffer = .{
                .buffer = buffer,
                .size = @sizeOf(Uniforms),
            } },
        }},
    });

    return .{
        .buffer = buffer,
        .bind_group_pool = bind_group_pool,
        .bind_group = bind_group,
    };
}

pub fn deinit(self: PreparedTransform) void {
    self.bind_group_pool.deinit();
    self.buffer.deinit();
}

pub fn system(
    commands: Commands,
    device: *vk.Device,
    pipeline: *Pipeline,
    transform_query: Query(struct {
        entity: Entity,
        transform: *Transform,
    }),
    prepared_query: Query(struct {
        prepared: *PreparedTransform,
    }),
) !void {
    var it = transform_query.iterator();
    while (it.next()) |transform| {
        if (!prepared_query.contains(transform.entity)) {
            std.log.debug("Preparing transform for entity: {}", .{transform.entity});

            const prepared = try PreparedTransform.init(
                device.*,
                pipeline.*,
            );
            errdefer prepared.deinit();

            try commands.addComponent(transform.entity, prepared);
        }
    }
}

pub const Uniforms = extern struct {
    model: [16]f32,
};

pub const Pipeline = struct {
    layout: vk.BindGroupLayout,

    pub fn init(device: vk.Device) !Pipeline {
        const layout = try device.createBindGroupLayout(.{
            .entries = &.{
                .{
                    .binding = 0,
                    .stages = .{ .vertex = true, .fragment = true },
                    .type = .UniformBuffer,
                },
            },
        });
        errdefer layout.deinit();

        return .{
            .layout = layout,
        };
    }

    pub fn deinit(self: Pipeline) void {
        self.layout.deinit();
    }
};
