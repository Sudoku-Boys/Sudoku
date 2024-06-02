const std = @import("std");
const vk = @import("vulkan");

const Commands = @import("../Commands.zig");
const Entity = @import("../Entity.zig");
const Query = @import("../query.zig").Query;
const GlobalTransform = @import("../GlobalTransform.zig");

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

pub fn update(
    self: PreparedTransform,
    staging_buffer: *vk.StagingBuffer,
    transform: GlobalTransform,
) !void {
    const u = Uniforms{
        .model = transform.computeMatrix().f,
    };

    try staging_buffer.write(&u);
    try staging_buffer.copyBuffer(.{
        .dst = self.buffer,
        .size = @sizeOf(Uniforms),
    });
}

pub fn system(
    commands: Commands,
    device: *vk.Device,
    staging_buffer: *vk.StagingBuffer,
    pipeline: *Pipeline,
    transform_query: Query(struct {
        entity: Entity,
        transform: *GlobalTransform,
    }),
    prepared_query: Query(struct {
        prepared: *PreparedTransform,
    }),
) !void {
    var it = transform_query.iterator();
    while (it.next()) |q| {
        if (prepared_query.fetch(q.entity)) |p| {
            try p.prepared.update(
                staging_buffer,
                q.transform.*,
            );
        } else {
            std.log.debug("Preparing transform for entity: {}", .{q.entity});

            const prepared = try PreparedTransform.init(
                device.*,
                pipeline.*,
            );
            errdefer prepared.deinit();

            try prepared.update(
                staging_buffer,
                q.transform.*,
            );

            try commands.addComponent(q.entity, prepared);
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
