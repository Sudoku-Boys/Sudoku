const std = @import("std");
const Window = @import("Window.zig");
const vk = @import("../vulkan/vk.zig");

const Renderer = @This();

fn createPbrPipeline(device: vk.Device, swapchain: vk.Swapchain) !vk.GraphicsPipeline {
    return try vk.GraphicsPipeline.init(device, .{
        .vertex = .{
            .shader = vk.embedSpv("shader/pbr.vert"),
            .entry_point = "main",
        },
        .fragment = .{
            .shader = vk.embedSpv("shader/pbr.frag"),
            .entry_point = "main",
        },
        .color_blend = .{
            .attachments = &.{.{
                .blend_enable = false,
            }},
        },
        .render_pass = swapchain.render_pass,
    });
}

window: Window,
instance: vk.Instance,
device: vk.Device,
swapchain: vk.Swapchain,
pbr_pipeline: vk.GraphicsPipeline,
graphics_pool: vk.CommandPool,
graphics_buffer: vk.CommandBuffer,
image_available_semaphore: vk.Semaphore,
render_finished_semaphore: vk.Semaphore,
in_flight_fence: vk.Fence,

pub fn init(allocator: std.mem.Allocator) !Renderer {
    const instance = try vk.Instance.init(allocator, .{
        .extensions = Window.queryVkExtensions(),
    });
    errdefer instance.deinit();

    const window = try Window.init(.{ .instance = instance });
    errdefer window.deinit();

    const device = try vk.Device.init(instance, window);
    errdefer device.deinit();

    var swapchain = try vk.Swapchain.init(device, window);
    errdefer swapchain.deinit();

    var pbr_pipeline = try createPbrPipeline(device, swapchain);
    errdefer pbr_pipeline.deinit();

    const graphics_pool = try vk.CommandPool.init(device, .Graphics);
    errdefer graphics_pool.deinit();

    const graphics_buffer = try graphics_pool.createCommandBuffer(.Primary);

    const image_available_semaphore = try device.createSemaphore();
    errdefer image_available_semaphore.deinit();

    const render_finished_semaphore = try device.createSemaphore();
    errdefer render_finished_semaphore.deinit();

    const in_flight_fence = try device.createFence(true);
    errdefer in_flight_fence.deinit();

    return .{
        .instance = instance,
        .window = window,
        .device = device,
        .swapchain = swapchain,
        .pbr_pipeline = pbr_pipeline,
        .graphics_pool = graphics_pool,
        .graphics_buffer = graphics_buffer,
        .image_available_semaphore = image_available_semaphore,
        .render_finished_semaphore = render_finished_semaphore,
        .in_flight_fence = in_flight_fence,
    };
}

pub fn deinit(self: Renderer) void {
    self.device.waitIdle() catch {};

    self.in_flight_fence.deinit();
    self.render_finished_semaphore.deinit();
    self.image_available_semaphore.deinit();
    self.graphics_pool.deinit();
    self.pbr_pipeline.deinit();
    self.swapchain.deinit();
    self.device.deinit();
    self.window.deinit();
    self.instance.deinit();
}

fn recordCommandBuffer(self: *Renderer, image: u32) !void {
    try self.graphics_buffer.reset();
    try self.graphics_buffer.begin();

    self.graphics_buffer.beginRenderPass(.{
        .render_pass = self.swapchain.render_pass,
        .framebuffer = self.swapchain.framebuffers[image],
        .render_area = .{
            .x = 0,
            .y = 0,
            .width = self.swapchain.extent.width,
            .height = self.swapchain.extent.height,
        },
    });

    self.graphics_buffer.bindGraphicsPipeline(self.pbr_pipeline);

    self.graphics_buffer.setViewport(.{
        .width = @floatFromInt(self.swapchain.extent.width),
        .height = @floatFromInt(self.swapchain.extent.height),
    });

    self.graphics_buffer.setScissor(.{
        .width = self.swapchain.extent.width,
        .height = self.swapchain.extent.height,
    });

    self.graphics_buffer.draw(3, 1, 0, 0);

    self.graphics_buffer.endRenderPass();

    try self.graphics_buffer.end();
}

pub fn tryDrawFrame(self: *Renderer) !void {
    try self.in_flight_fence.wait(.{});
    try self.in_flight_fence.reset();

    const image = try self.swapchain.aquireNextImage(.{
        .semaphore = self.image_available_semaphore,
    });

    try self.recordCommandBuffer(image);

    try self.device.graphics.submit(.{
        .wait_semaphores = &.{
            .{
                .semaphore = self.image_available_semaphore,
                .stage = .{ .color_attachment_output = true },
            },
        },
        .command_buffers = &.{
            self.graphics_buffer,
        },
        .signal_semaphores = &.{
            self.render_finished_semaphore,
        },
        .fence = self.in_flight_fence,
    });

    try self.device.present.present(.{
        .swapchains = &.{
            .{
                .swapchain = self.swapchain,
                .image = image,
            },
        },
        .wait_semaphores = &.{
            self.render_finished_semaphore,
        },
    });
}

pub fn drawFrame(self: *Renderer) !void {
    self.tryDrawFrame() catch |err| switch (err) {
        error.VK_ERROR_OUT_OF_DATE_KHR => return try self.swapchain.recreate(),
        else => return err,
    };
}
