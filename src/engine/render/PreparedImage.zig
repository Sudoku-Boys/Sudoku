const std = @import("std");
const vk = @import("vulkan");

const asset = @import("../asset.zig");
const event = @import("../event.zig");

const Image = @import("../Image.zig");

const PreparedImage = @This();

image: vk.Image,
view: vk.ImageView,
sampler: vk.Sampler,

pub fn fallback(device: vk.Device, staging_buffer: *vk.StagingBuffer, color: u32) !PreparedImage {
    const vk_image = try device.createImage(.{
        .format = .R8G8B8A8Unorm,
        .extent = .{ .width = 1, .height = 1, .depth = 1 },
        .usage = .{
            .sampled = true,
            .transfer_dst = true,
        },
    });

    try staging_buffer.write(&std.mem.nativeToBig(u32, color));
    try staging_buffer.copyImage(.{
        .dst = vk_image,
        .aspect = .{ .color = true },
        .old_layout = .Undefined,
        .new_layout = .ShaderReadOnlyOptimal,
        .extent = .{ .width = 1, .height = 1, .depth = 1 },
    });

    return .{
        .image = vk_image,
        .view = try vk_image.createView(.{
            .aspect = .{ .color = true },
        }),
        .sampler = try device.createSampler(.{}),
    };
}

pub fn deinit(self: PreparedImage) void {
    self.image.deinit();
    self.view.deinit();
    self.sampler.deinit();
}

pub fn system(
    events: event.EventReader(asset.AssetEvent(Image)),
    device: *vk.Device,
    staging_buffer: *vk.StagingBuffer,
    images: *asset.Assets(Image),
    prepared: *asset.Assets(PreparedImage),
) !void {
    while (events.next()) |e| {
        switch (e) {
            .Added, .Modified => |id| {
                const image = images.get(id).?;
                const vk_image = try device.createImage(.{
                    .format = switch (image.format) {
                        .Srgb => .R8G8B8A8Srgb,
                        .Linear => .R8G8B8A8Unorm,
                    },
                    .extent = .{
                        .width = image.width,
                        .height = image.height,
                        .depth = 1,
                    },
                    .usage = .{
                        .sampled = true,
                        .transfer_dst = true,
                    },
                });

                try staging_buffer.write(image.data);
                try staging_buffer.copyImage(.{
                    .dst = vk_image,
                    .aspect = .{ .color = true },
                    .old_layout = .Undefined,
                    .new_layout = .ShaderReadOnlyOptimal,
                    .extent = .{
                        .width = image.width,
                        .height = image.height,
                        .depth = 1,
                    },
                });

                const filter = switch (image.filter) {
                    .Nearest => vk.Filter.Nearest,
                    .Linear => vk.Filter.Linear,
                };

                _ = try prepared.put(id.cast(PreparedImage), .{
                    .image = vk_image,
                    .view = try vk_image.createView(.{
                        .aspect = .{ .color = true },
                    }),
                    .sampler = try device.createSampler(.{
                        .mag_filter = filter,
                        .min_filter = filter,
                    }),
                });
            },
            .Removed => |id| {
                try prepared.remove(id.cast(PreparedImage));
            },
        }
    }
}
