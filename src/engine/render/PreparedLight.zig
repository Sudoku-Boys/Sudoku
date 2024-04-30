const std = @import("std");
const vk = @import("vulkan");

const Downsample = @import("Downsample.zig");

const PreparedLight = @This();

bind_group_layout: vk.BindGroupLayout,
bind_group_pool: vk.BindGroupPool,
bind_group: vk.BindGroup,

transmission_downsample: Downsample,
transmission_image: vk.Image,
transmission_image_view: vk.ImageView,
transmission_sampler: vk.Sampler,

pub fn init(
    device: vk.Device,
    target: vk.Image,
) !PreparedLight {
    const bind_group_layout = try device.createBindGroupLayout(.{
        .entries = &.{
            .{
                .binding = 0,
                .stages = .{ .fragment = true },
                .type = .CombinedImageSampler,
            },
        },
    });
    errdefer bind_group_layout.deinit();

    const bind_group_pool = try device.createBindGroupPool(.{
        .pool_sizes = &.{
            .{
                .type = .CombinedImageSampler,
                .count = 1,
            },
        },
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const bind_group = try bind_group_pool.alloc(bind_group_layout);

    const transmission_image = try createTransmissionImage(device, target);
    errdefer transmission_image.deinit();

    const transmission_image_view = try transmission_image.createView(.{
        .aspect = .{ .color = true },
        .mip_levels = transmission_image.mip_levels,
    });
    errdefer transmission_image_view.deinit();

    const transmission_sampler = try device.createSampler(.{
        .min_filter = .Linear,
        .mag_filter = .Linear,
        .address_mode_u = .ClampToEdge,
        .address_mode_v = .ClampToEdge,
        .address_mode_w = .ClampToEdge,
        .mipmap_mode = .Linear,
        .min_lod = 0.0,
        .max_lod = 100.0,
    });
    errdefer transmission_sampler.deinit();

    device.updateBindGroups(.{
        .writes = &.{
            .{
                .dst = bind_group,
                .binding = 0,
                .resource = .{
                    .combined_image = .{
                        .layout = .ShaderReadOnlyOptimal,
                        .view = transmission_image_view,
                        .sampler = transmission_sampler,
                    },
                },
            },
        },
    });

    var transmission_downsample = try Downsample.init(device);
    errdefer transmission_downsample.deinit();

    try transmission_downsample.setImage(device, transmission_image);

    return .{
        .bind_group_layout = bind_group_layout,
        .bind_group_pool = bind_group_pool,
        .bind_group = bind_group,

        .transmission_downsample = transmission_downsample,
        .transmission_image = transmission_image,
        .transmission_image_view = transmission_image_view,
        .transmission_sampler = transmission_sampler,
    };
}

pub fn deinit(self: PreparedLight) void {
    self.transmission_downsample.deinit();
    self.transmission_image_view.deinit();
    self.transmission_image.deinit();
    self.transmission_sampler.deinit();

    self.bind_group_pool.deinit();
}

fn createTransmissionImage(device: vk.Device, target: vk.Image) !vk.Image {
    const min_extent = @min(target.extent.width, target.extent.height);
    const mip_level = std.math.log2(min_extent) + 1;

    return try device.createImage(.{
        .format = target.format,
        .extent = target.extent,
        .mip_levels = mip_level,
        .usage = .{
            .transfer_dst = true,
            .sampled = true,
            .storage = true,
        },
        .memory = .{ .device_local = true },
    });
}

pub fn setTarget(self: *PreparedLight, device: vk.Device, target: vk.Image) !void {
    self.transmission_image.deinit();
    self.transmission_image = try createTransmissionImage(device, target);
    try self.transmission_downsample.setImage(device, self.transmission_image);

    self.transmission_image_view.deinit();
    self.transmission_image_view = try self.transmission_image.createView(.{
        .aspect = .{ .color = true },
        .mip_levels = self.transmission_image.mip_levels,
    });

    device.updateBindGroups(.{
        .writes = &.{
            .{
                .dst = self.bind_group,
                .binding = 0,
                .resource = .{
                    .combined_image = .{
                        .layout = .ShaderReadOnlyOptimal,
                        .view = self.transmission_image_view,
                        .sampler = self.transmission_sampler,
                    },
                },
            },
        },
    });
}
