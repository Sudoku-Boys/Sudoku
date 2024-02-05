const std = @import("std");
const vk = @import("vulkan");

const Renderer = @This();

const Hdr = struct {
    color_image: vk.Image,
    color_view: vk.ImageView,
    depth_image: vk.Image,
    depth_view: vk.ImageView,
    render_pass: vk.RenderPass,
    framebuffer: vk.Framebuffer,

    const COLOR_FORMAT = vk.ImageFormat.R16G16B16A16Sfloat;
    const DEPTH_FORMAT = vk.ImageFormat.D32Sfloat;

    fn init(device: vk.Device, extent: vk.Extent2D) !Hdr {
        const color_image = try vk.Image.init(device, .{
            .format = Hdr.COLOR_FORMAT,
            .extent = .{
                .width = extent.width,
                .height = extent.height,
                .depth = 1,
            },
            .usage = .{ .color_attachment = true, .sampled = true },
            .memory = .{ .device_local = true },
        });
        errdefer color_image.deinit();

        const color_view = try color_image.createView(.{
            .format = Hdr.COLOR_FORMAT,
            .aspect = .{ .color = true },
        });
        errdefer color_view.deinit();

        const depth_image = try vk.Image.init(device, .{
            .format = Hdr.DEPTH_FORMAT,
            .extent = .{
                .width = extent.width,
                .height = extent.height,
                .depth = 1,
            },
            .usage = .{ .depth_stencil_attachment = true },
            .memory = .{ .device_local = true },
        });
        errdefer depth_image.deinit();

        const depth_view = try depth_image.createView(.{
            .format = Hdr.DEPTH_FORMAT,
            .aspect = .{ .depth = true },
        });
        errdefer depth_view.deinit();

        const render_pass = try createHdrRenderPass(device);
        errdefer render_pass.deinit();

        const framebuffer = try vk.Framebuffer.init(device, .{
            .render_pass = render_pass,
            .attachments = &.{ color_view, depth_view },
            .extent = .{
                .width = extent.width,
                .height = extent.height,
            },
        });

        return .{
            .color_image = color_image,
            .color_view = color_view,
            .depth_image = depth_image,
            .depth_view = depth_view,
            .render_pass = render_pass,
            .framebuffer = framebuffer,
        };
    }

    fn deinit(self: Hdr) void {
        self.framebuffer.deinit();
        self.render_pass.deinit();
        self.depth_view.deinit();
        self.depth_image.deinit();
        self.color_view.deinit();
        self.color_image.deinit();
    }
};

const Sdr = struct {
    swapchain: vk.Swapchain,
    render_pass: vk.RenderPass,
    format: vk.ImageFormat,

    fn init(device: vk.Device, surface: vk.Surface) !Sdr {
        const format = try device.querySurfaceFormat(surface);
        const render_pass = try createSdrRenderPass(device, format);
        const swapchain = try vk.Swapchain.init(device, surface, render_pass);

        return .{
            .swapchain = swapchain,
            .render_pass = render_pass,
            .format = swapchain.format,
        };
    }

    fn deinit(self: Sdr) void {
        self.render_pass.deinit();
        self.swapchain.deinit();
    }
};

allocator: std.mem.Allocator,
device: vk.Device,
surface: vk.Surface,

sdr: Sdr,
hdr: Hdr,

graphics_pool: vk.CommandPool,
graphics_buffer: vk.CommandBuffer,

in_flight: vk.Fence,
image_available: vk.Semaphore,
render_finished: vk.Semaphore,

pub const Descriptor = struct {
    allocator: std.mem.Allocator,
    device: vk.Device,
    surface: vk.Surface,
};

pub fn init(desc: Descriptor) !Renderer {
    const sdr = try Sdr.init(desc.device, desc.surface);
    errdefer sdr.deinit();

    const hdr = try Hdr.init(desc.device, sdr.swapchain.extent);
    errdefer hdr.deinit();

    const graphics_pool = try vk.CommandPool.init(desc.device, .Graphics);
    errdefer graphics_pool.deinit();

    const graphics_buffer = try graphics_pool.alloc(.Primary);

    const in_flight = try desc.device.createFence(true);
    errdefer in_flight.deinit();

    const image_available = try desc.device.createSemaphore();
    errdefer image_available.deinit();

    const render_finished = try desc.device.createSemaphore();
    errdefer render_finished.deinit();

    return .{
        .allocator = desc.allocator,
        .device = desc.device,
        .surface = desc.surface,

        .sdr = sdr,
        .hdr = hdr,

        .graphics_pool = graphics_pool,
        .graphics_buffer = graphics_buffer,

        .in_flight = in_flight,
        .image_available = image_available,
        .render_finished = render_finished,
    };
}

pub fn deinit(self: Renderer) void {
    self.render_finished.deinit();
    self.image_available.deinit();
    self.in_flight.deinit();

    self.graphics_pool.deinit();

    self.hdr.deinit();
    self.sdr.deinit();
}

fn createSdrRenderPass(device: vk.Device, format: vk.ImageFormat) !vk.RenderPass {
    return vk.RenderPass.init(device, .{
        .attachments = &.{
            .{
                .format = format,
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
                .src_stage_mask = .{ .color_attachment_output = true },
                .dst_stage_mask = .{ .color_attachment_output = true },
                .dst_access_mask = .{ .color_attachment_write = true },
            },
        },
    });
}

fn createHdrRenderPass(device: vk.Device) !vk.RenderPass {
    return vk.RenderPass.init(device, .{
        .attachments = &.{
            .{
                .format = Hdr.COLOR_FORMAT,
                .samples = 1,
                .load_op = .Clear,
                .store_op = .Store,
                .final_layout = .ColorAttachmentOptimal,
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
                .src_stage_mask = .{ .color_attachment_output = true },
                .dst_stage_mask = .{ .color_attachment_output = true },
                .dst_access_mask = .{ .color_attachment_write = true },
            },
        },
    });
}

fn recordCommandBuffer(self: *Renderer, image_index: usize) !void {
    try self.graphics_buffer.reset();
    try self.graphics_buffer.begin(.{ .one_time_submit = true });

    self.graphics_buffer.beginRenderPass(.{
        .render_pass = self.hdr.render_pass,
        .framebuffer = self.hdr.framebuffer,
    });

    self.graphics_buffer.endRenderPass();

    self.graphics_buffer.beginRenderPass(.{
        .render_pass = self.sdr.render_pass,
        .framebuffer = self.sdr.swapchain.framebuffers[image_index],
    });

    self.graphics_buffer.endRenderPass();

    try self.graphics_buffer.end();
}

pub fn drawFrame(self: *Renderer) !void {
    try self.in_flight.wait(.{});

    const image_index = self.sdr.swapchain.acquireNextImage(.{
        .semaphore = self.image_available,
    }) catch |err| switch (err) {
        else => return err,
    };

    try self.in_flight.reset();

    try self.recordCommandBuffer(image_index);

    try self.device.graphics.submit(.{
        .wait_semaphores = &.{
            .{
                .semaphore = self.image_available,
                .stage = .{ .color_attachment_output = true },
            },
        },
        .command_buffers = &.{
            self.graphics_buffer,
        },
        .signal_semaphores = &.{
            self.render_finished,
        },
        .fence = self.in_flight,
    });

    try self.device.present.present(.{
        .swapchains = &.{
            .{
                .swapchain = self.sdr.swapchain,
                .image_index = image_index,
            },
        },
        .wait_semaphores = &.{
            self.render_finished,
        },
    });
}
