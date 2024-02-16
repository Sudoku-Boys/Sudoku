const std = @import("std");
const vk = @import("vulkan");

const Camera = @import("Camera.zig");
const Material = @import("Material.zig");

const CameraState = @This();

buffer: vk.Buffer,
bind_group_pool: vk.BindGroupPool,
bind_group: vk.BindGroup,

pub fn init(
    device: vk.Device,
    layouts: Material.BindGroupLayouts,
) !CameraState {
    const bind_group_pool = try device.createBindGroupPool(.{
        .pool_sizes = &.{
            .{
                .type = .UniformBuffer,
                .count = 1,
            },
        },
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const buffer = try device.createBuffer(.{
        .size = @sizeOf(Camera.Uniforms),
        .usage = .{ .uniform_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer buffer.deinit();

    const bind_group = try bind_group_pool.alloc(layouts.camera);

    device.updateBindGroups(.{
        .writes = &.{
            .{
                .dst = bind_group,
                .binding = 0,
                .resource = .{
                    .buffer = .{
                        .buffer = buffer,
                        .size = @sizeOf(Camera.Uniforms),
                    },
                },
            },
        },
    });

    return .{
        .buffer = buffer,
        .bind_group_pool = bind_group_pool,
        .bind_group = bind_group,
    };
}

pub fn deinit(self: CameraState) void {
    self.bind_group_pool.deinit();
    self.buffer.deinit();
}

pub fn prepare(self: *CameraState, staging_buffer: *vk.StagingBuffer, uniforms: Camera.Uniforms) !void {
    try staging_buffer.write(&uniforms);
    try staging_buffer.copyBuffer(.{
        .dst = self.buffer,
        .size = @sizeOf(Camera.Uniforms),
    });
}
