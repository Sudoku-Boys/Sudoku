const std = @import("std");
const vk = @import("vulkan");

const Downsample = @This();

bind_group_layout: vk.BindGroupLayout,
bind_group_pool: vk.BindGroupPool,
bind_group: vk.BindGroup,
pipeline: vk.ComputePipeline,

pub fn init(device: vk.Device) !Downsample {
    const bind_group_layout = try device.createBindGroupLayout(.{
        .entries = &.{
            .{
                .binding = 0,
                .type = .StorageImage,
                .stages = .{ .compute = true },
            },
        },
    });
    errdefer bind_group_layout.deinit();

    const bind_group_pool = try device.createBindGroupPool(.{
        .pool_sizes = &.{
            .{
                .type = .StorageImage,
                .count = 1,
            },
        },
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const bind_group = try bind_group_pool.alloc(bind_group_layout);

    const pipeline = try device.createComputePipeline(.{
        .shader = vk.embedSpirv(@embedFile("shaders/downsample.comp")),
        .entry_point = "main",
        .layout = &.{bind_group_layout},
    });
    errdefer pipeline.deinit();

    return .{
        .bind_group_layout = bind_group_layout,
        .bind_group_pool = bind_group_pool,
        .bind_group = bind_group,
        .pipeline = pipeline,
    };
}

pub fn deinit(self: Downsample) void {
    self.pipeline.deinit();
    self.bind_group_pool.deinit();
    self.bind_group_layout.deinit();
}

pub fn setImage(self: Downsample, device: vk.Device, image: vk.Image) !void {
    const view = try image.createView(.{
        .format = image.format,
        .aspect = .{ .color = true },
    });
    defer view.deinit();

    device.updateBindGroups(.{
        .writes = &.{
            .{
                .dst = self.bind_group,
                .binding = 0,
                .resource = .{
                    .storage_image = .{
                        .view = view,
                        .layout = .General,
                    },
                },
            },
        },
    });
}

pub fn dispatch(self: Downsample, command_buffer: vk.CommandBuffer, image: vk.Image) void {
    command_buffer.bindComputePipeline(self.pipeline);
    command_buffer.bindBindGroup(self.pipeline, 0, self.bind_group, &.{});
    command_buffer.dispatch(image.extent.width / 6, image.extent.height / 8, 1);
}
