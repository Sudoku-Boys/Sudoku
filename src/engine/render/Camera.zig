const std = @import("std");
const vk = @import("vulkan");
const math = @import("../math.zig");

const Commands = @import("../Commands.zig");
const Entity = @import("../Entity.zig");
const Query = @import("../query.zig").Query;
const Transform = @import("../Transform.zig");

const Sdr = @import("Sdr.zig");

const Camera = @This();

pub const Uniforms = extern struct {
    view: [16]f32,
    proj: [16]f32,
    view_proj: [16]f32,
    inv_view_proj: [16]f32,
    eye: [3]f32,
    _padding0: [4]u8 = undefined,
};

fov: f32 = 70.0,
near: f32 = 0.1,
far: f32 = 100.0,

pub fn proj(self: Camera, aspect: f32) math.Mat4 {
    return math.Mat4.projection(
        aspect,
        self.fov / 360.0,
        self.near,
        self.far,
    );
}

pub fn uniforms(self: Camera, transform: Transform, aspect: f32) Uniforms {
    const view_matrix = transform.computeMatrix();
    const proj_matrix = self.proj(aspect);
    const view_proj_matrix = view_matrix.inv().mul(proj_matrix);
    const inv_view_proj_matrix = view_proj_matrix.inv();

    const eye = transform.translation;

    return Uniforms{
        .view = view_matrix.f,
        .proj = proj_matrix.f,
        .view_proj = view_proj_matrix.f,
        .inv_view_proj = inv_view_proj_matrix.f,
        .eye = eye.swizzle("xyz").v,
    };
}

pub const Pipeline = struct {
    layout: vk.BindGroupLayout,

    pub fn init(device: vk.Device) !Pipeline {
        const layout = try device.createBindGroupLayout(.{
            .entries = &.{.{
                .binding = 0,
                .type = .UniformBuffer,
                .stages = .{ .vertex = true, .fragment = true },
            }},
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

pub const Prepared = struct {
    buffer: vk.Buffer,
    bind_group_pool: vk.BindGroupPool,
    bind_group: vk.BindGroup,

    pub fn init(
        device: vk.Device,
        pipeline: Pipeline,
    ) !Prepared {
        const bind_group_pool = try device.createBindGroupPool(.{
            .pool_sizes = &.{.{
                .type = .UniformBuffer,
                .count = 1,
            }},
            .max_groups = 1,
        });
        errdefer bind_group_pool.deinit();

        const buffer = try device.createBuffer(.{
            .size = @sizeOf(Uniforms),
            .usage = .{ .uniform_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });
        errdefer buffer.deinit();

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

    pub fn deinit(self: Prepared) void {
        self.bind_group_pool.deinit();
        self.buffer.deinit();
    }

    pub fn update(
        self: Prepared,
        staging_buffer: *vk.StagingBuffer,
        camera: Camera,
        transform: Transform,
        aspect: f32,
    ) !void {
        const u = camera.uniforms(transform, aspect);

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
        sdr: *Sdr,
        camera_query: Query(struct {
            entity: Entity,
            transform: *Transform,
            camera: *Camera,
        }),
        prepared_query: Query(struct {
            prepared: *Prepared,
        }),
    ) !void {
        const aspect = sdr.swapchain.extent.aspectRatio();

        var it = camera_query.iterator();
        while (it.next()) |camera| {
            if (prepared_query.fetch(camera.entity)) |p| {
                try p.prepared.update(
                    staging_buffer,
                    camera.camera.*,
                    camera.transform.*,
                    aspect,
                );
            } else {
                std.log.debug("Preparing camera bind group for entity {}", .{camera.entity});

                const prepared = try Prepared.init(
                    device.*,
                    pipeline.*,
                );
                errdefer prepared.deinit();

                try prepared.update(
                    staging_buffer,
                    camera.camera.*,
                    camera.transform.*,
                    aspect,
                );

                try commands.addComponent(camera.entity, prepared);
            }
        }
    }
};
