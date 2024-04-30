const std = @import("std");
const vk = @import("vulkan");

const Hdr = @This();

color_image: vk.Image,
color_view: vk.ImageView,
depth_image: vk.Image,
depth_view: vk.ImageView,

render_pass: vk.RenderPass,
framebuffer: vk.Framebuffer,

pub const COLOR_FORMAT = vk.ImageFormat.R16G16B16A16Sfloat;
pub const DEPTH_FORMAT = vk.ImageFormat.D32Sfloat;

pub fn init(device: vk.Device, extent: vk.Extent3D) !Hdr {
    const color_image = try createColorImage(device, extent);
    errdefer color_image.deinit();

    const color_view = try color_image.createView(.{
        .format = COLOR_FORMAT,
        .aspect = .{ .color = true },
    });
    errdefer color_view.deinit();

    const depth_image = try createDepthImage(device, extent);
    errdefer depth_image.deinit();

    const depth_view = try depth_image.createView(.{
        .format = DEPTH_FORMAT,
        .aspect = .{ .depth = true },
    });
    errdefer depth_view.deinit();

    const render_pass = try createRenderPass(device);
    errdefer render_pass.deinit();

    const framebuffer = try render_pass.createFramebuffer(.{
        .attachments = &.{
            color_view,
            depth_view,
        },
        .extent = extent.as2D(),
    });
    errdefer framebuffer.deinit();

    return .{
        .color_image = color_image,
        .color_view = color_view,
        .depth_image = depth_image,
        .depth_view = depth_view,

        .render_pass = render_pass,
        .framebuffer = framebuffer,
    };
}

pub fn deinit(self: Hdr) void {
    self.color_view.deinit();
    self.color_image.deinit();
    self.depth_view.deinit();
    self.depth_image.deinit();

    self.framebuffer.deinit();
    self.render_pass.deinit();
}

pub fn recreate(self: *Hdr, device: vk.Device, extent: vk.Extent3D) !void {
    self.color_image.deinit();
    self.color_image = try createColorImage(device, extent);

    self.color_view.deinit();
    self.color_view = try self.color_image.createView(.{
        .format = Hdr.COLOR_FORMAT,
        .aspect = .{ .color = true },
    });

    self.depth_image.deinit();
    self.depth_image = try createDepthImage(device, extent);

    self.depth_view.deinit();
    self.depth_view = try self.depth_image.createView(.{
        .format = Hdr.DEPTH_FORMAT,
        .aspect = .{ .depth = true },
    });

    self.framebuffer.deinit();
    self.framebuffer = try self.render_pass.createFramebuffer(.{
        .attachments = &.{
            self.color_view,
            self.depth_view,
        },
        .extent = extent.as2D(),
    });
}

fn createColorImage(device: vk.Device, extent: vk.Extent3D) !vk.Image {
    return try device.createImage(.{
        .format = COLOR_FORMAT,
        .extent = extent,
        .usage = .{
            .color_attachment = true,
            .transfer_src = true,
            .sampled = true,
        },
        .memory = .{ .device_local = true },
    });
}

fn createDepthImage(device: vk.Device, extent: vk.Extent3D) !vk.Image {
    return try device.createImage(.{
        .format = vk.ImageFormat.D32Sfloat,
        .extent = extent,
        .usage = .{
            .depth_stencil_attachment = true,
            .transfer_src = true,
            .sampled = true,
        },
        .memory = .{ .device_local = true },
    });
}

fn createRenderPass(device: vk.Device) !vk.RenderPass {
    return device.createRenderPass(.{
        .attachments = &.{
            .{
                .format = Hdr.COLOR_FORMAT,
                .samples = 1,
                .load_op = .Load,
                .store_op = .Store,
                .initial_layout = .ColorAttachmentOptimal,
                .final_layout = .ShaderReadOnlyOptimal,
            },
            .{
                .format = Hdr.DEPTH_FORMAT,
                .samples = 1,
                .load_op = .Clear,
                .store_op = .Store,
                .final_layout = .DepthStencilAttachmentOptimal,
            },
        },
        .subpasses = &.{
            .{
                .color_attachments = &.{
                    .{
                        .attachment = 0,
                        .layout = .ColorAttachmentOptimal,
                    },
                },
                .depth_stencil_attachment = .{
                    .attachment = 1,
                    .layout = .DepthStencilAttachmentOptimal,
                },
            },
        },
        .dependencies = &.{
            .{
                .dst_subpass = 0,
                .src_stage_mask = .{
                    .top_of_pipe = true,
                },
                .dst_stage_mask = .{
                    .color_attachment_output = true,
                    .early_fragment_tests = true,
                },
                .dst_access_mask = .{
                    .depth_stencil_attachment_read = true,
                    .depth_stencil_attachment_write = true,
                    .color_attachment_write = true,
                },
            },
            .{
                .src_subpass = 0,
                .src_stage_mask = .{
                    .color_attachment_output = true,
                },
                .src_access_mask = .{
                    .color_attachment_write = true,
                },
                .dst_stage_mask = .{
                    .fragment_shader = true,
                },
                .dst_access_mask = .{
                    .shader_read = true,
                },
            },
        },
    });
}
