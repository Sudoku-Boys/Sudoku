const std = @import("std");
const vk = @import("vulkan");

const Sdr = @This();

allocator: std.mem.Allocator,
swapchain: vk.Swapchain,

render_pass: vk.RenderPass,
framebuffers: []vk.Framebuffer,

pub const COLOR_FORMAT: vk.ImageFormat = vk.ImageFormat.B8G8R8A8Unorm;

pub fn init(
    allocator: std.mem.Allocator,
    device: vk.Device,
    surface: vk.Surface,
    extent: vk.Extent2D,
    present_mode: vk.PresentMode,
) !Sdr {
    const render_pass = try createRenderPass(device);
    const swapchain = try device.createSwapchain(.{
        .extent = extent,
        .surface = surface,
        .present_mode = present_mode,
    });

    const framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.images.len);

    for (swapchain.views, 0..) |view, i| {
        framebuffers[i] = try render_pass.createFramebuffer(.{
            .attachments = &.{view},
            .extent = swapchain.extent.as2D(),
        });
    }

    return .{
        .allocator = allocator,
        .swapchain = swapchain,
        .render_pass = render_pass,
        .framebuffers = framebuffers,
    };
}

pub fn deinit(self: Sdr) void {
    for (self.framebuffers) |framebuffer| {
        framebuffer.deinit();
    }

    self.allocator.free(self.framebuffers);

    self.render_pass.deinit();
    self.swapchain.deinit();
}

fn createRenderPass(device: vk.Device) !vk.RenderPass {
    return vk.RenderPass.init(device, .{
        .attachments = &.{
            .{
                .format = Sdr.COLOR_FORMAT,
                .samples = 1,
                .load_op = .Clear,
                .store_op = .Store,
                .final_layout = .PresentSrc,
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
            },
        },
        .dependencies = &.{
            .{
                .dst_subpass = 0,
                .src_stage_mask = .{
                    .fragment_shader = true,
                },
                .dst_stage_mask = .{
                    .color_attachment_output = true,
                },
                .dst_access_mask = .{
                    .color_attachment_write = true,
                },
            },
        },
    });
}

pub fn recreate(self: *Sdr, extent: vk.Extent2D) !void {
    for (self.framebuffers) |framebuffer| {
        framebuffer.deinit();
    }

    try self.swapchain.recreate(extent);

    self.framebuffers = try self.allocator.realloc(self.framebuffers, self.swapchain.images.len);

    for (self.swapchain.views, 0..) |view, i| {
        self.framebuffers[i] = try self.render_pass.createFramebuffer(.{
            .attachments = &.{view},
            .extent = self.swapchain.extent.as2D(),
        });
    }
}
