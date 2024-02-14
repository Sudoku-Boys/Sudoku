const std = @import("std");
const vk = @import("vulkan");

const Downsample = @This();

bind_group_layout: vk.BindGroupLayout,
bind_group_pool: vk.BindGroupPool,
bind_groups: [16]vk.BindGroup,
views: [32]?vk.ImageView,
sampler: vk.Sampler,
pipeline: vk.ComputePipeline,

pub fn init(device: vk.Device) !Downsample {
    const bind_group_layout = try device.createBindGroupLayout(.{
        .entries = &.{
            .{
                .binding = 0,
                .type = .CombinedImageSampler,
                .stages = .{ .compute = true },
            },
            .{
                .binding = 1,
                .type = .StorageImage,
                .stages = .{ .compute = true },
            },
        },
    });
    errdefer bind_group_layout.deinit();

    const bind_group_pool = try device.createBindGroupPool(.{
        .pool_sizes = &.{
            .{
                .type = .CombinedImageSampler,
                .count = 16,
            },
            .{
                .type = .StorageImage,
                .count = 16,
            },
        },
        .max_groups = 16,
    });
    errdefer bind_group_pool.deinit();

    var bind_groups: [16]vk.BindGroup = undefined;
    for (0..16) |i| {
        bind_groups[i] = try bind_group_pool.alloc(bind_group_layout);
    }

    const sampler = try device.createSampler(.{
        .min_filter = .Linear,
        .mag_filter = .Linear,
        .mipmap_mode = .Linear,
        .address_mode_u = .ClampToEdge,
        .address_mode_v = .ClampToEdge,
        .address_mode_w = .ClampToEdge,
        .min_lod = 0.0,
        .max_lod = 16.0,
    });

    const pipeline = try device.createComputePipeline(.{
        .shader = vk.embedSpirv(@embedFile("shaders/downsample.comp")),
        .entry_point = "main",
        .layout = &.{bind_group_layout},
    });
    errdefer pipeline.deinit();

    return .{
        .bind_group_layout = bind_group_layout,
        .bind_group_pool = bind_group_pool,
        .bind_groups = bind_groups,
        .views = .{null} ** 32,
        .sampler = sampler,
        .pipeline = pipeline,
    };
}

pub fn deinit(self: Downsample) void {
    for (self.views) |optional_view| {
        if (optional_view) |view| view.deinit();
    }

    self.pipeline.deinit();
    self.sampler.deinit();
    self.bind_group_pool.deinit();
    self.bind_group_layout.deinit();
}

pub fn setImage(self: *Downsample, device: vk.Device, image: vk.Image) !void {
    for (0..image.mip_levels - 1) |i| {
        if (self.views[i * 2] != null) {
            self.views[i * 2 + 0].?.deinit();
            self.views[i * 2 + 1].?.deinit();
        }

        const src_view = try image.createView(.{
            .format = image.format,
            .aspect = .{ .color = true },
            .base_mip_level = @intCast(i),
        });
        errdefer src_view.deinit();

        const dst_view = try image.createView(.{
            .format = image.format,
            .aspect = .{ .color = true },
            .base_mip_level = @intCast(i + 1),
        });
        errdefer dst_view.deinit();

        device.updateBindGroups(.{
            .writes = &.{
                .{
                    .dst = self.bind_groups[i],
                    .binding = 0,
                    .resource = .{
                        .combined_image = .{
                            .view = src_view,
                            .sampler = self.sampler,
                            .layout = .General,
                        },
                    },
                },
                .{
                    .dst = self.bind_groups[i],
                    .binding = 1,
                    .resource = .{
                        .storage_image = .{
                            .view = dst_view,
                            .layout = .General,
                        },
                    },
                },
            },
        });

        self.views[i * 2 + 0] = src_view;
        self.views[i * 2 + 1] = dst_view;
    }
}

pub fn dispatch(self: Downsample, command_buffer: vk.CommandBuffer, image: vk.Image) void {
    command_buffer.bindComputePipeline(self.pipeline);

    for (0..image.mip_levels - 1) |i| {
        command_buffer.bindBindGroup(self.pipeline, 0, self.bind_groups[i], &.{});

        const x = (image.extent.width >> @intCast(i)) / 8;
        const y = (image.extent.height >> @intCast(i)) / 8;
        command_buffer.dispatch(@max(x, 1), @max(y, 1), 1);

        command_buffer.pipelineBarrier(.{
            .src_stage = .{ .compute_shader = true },
            .dst_stage = .{ .compute_shader = true },
        });
    }
}
