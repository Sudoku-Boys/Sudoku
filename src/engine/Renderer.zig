const std = @import("std");
const Window = @import("Window.zig");
const vk = @import("../vulkan/vk.zig");

const Renderer = @This();

fn createPbrPipeline(
    device: vk.Device,
    swapchain: vk.Swapchain,
    bind_group: vk.BindGroupLayout,
) !vk.GraphicsPipeline {
    return try vk.GraphicsPipeline.init(device, .{
        .vertex = .{
            .shader = vk.embedSpv("shader/StandardMaterial.vert"),
            .entry_point = "main",
            .bindings = &.{.{
                .binding = 0,
                .stride = 3 * 4,
                .input_rate = .Vertex,
                .attributes = &.{.{
                    .location = 0,
                    .format = .f32x3,
                    .offset = 0,
                }},
            }},
        },
        .fragment = .{
            .shader = vk.embedSpv("shader/StandardMaterial.frag"),
            .entry_point = "main",
        },
        .color_blend = .{
            .attachments = &.{.{
                .blend_enable = false,
            }},
        },
        .render_pass = swapchain.render_pass,
        .bind_groups = &.{bind_group},
        .subpass = 0,
    });
}

fn createRenderPass(device: vk.Device, format: vk.api.VkFormat) !vk.RenderPass {
    return try vk.RenderPass.init(
        device,
        .{
            .attachments = &.{.{
                .format = format,
                .samples = 1,
                .load_op = .Clear,
                .store_op = .Store,
                .final_layout = .PresentSrc,
            }},
            .subpasses = &.{.{
                .color_attachments = &.{.{
                    .attachment = 0,
                    .layout = .ColorAttachmentOptimal,
                }},
            }},
            .dependencies = &.{.{
                .src_subpass = vk.SUBPASS_EXTERNAL,
                .dst_subpass = 0,
                .src_stage_mask = .{ .color_attachment_output = true },
                .dst_stage_mask = .{ .color_attachment_output = true },
                .dst_access_mask = .{ .color_attachment_write = true },
            }},
        },
    );
}

window: Window,
instance: vk.Instance,
device: vk.Device,
render_pass: vk.RenderPass,
swapchain: vk.Swapchain,
pbr_pipeline: vk.GraphicsPipeline,
graphics_pool: vk.CommandPool,
graphics_buffer: vk.CommandBuffer,

bind_pool: vk.BindGroupPool,
bind_group_layout: vk.BindGroupLayout,
bind_group: vk.BindGroup,

staging_buffer: vk.StagingBuffer,
uniform_buffer: vk.Buffer,

image: vk.Image,
view: vk.ImageView,
sampler: vk.Sampler,

vertex_buffer: vk.Buffer,
index_buffer: vk.Buffer,

image_available_semaphore: vk.Semaphore,
render_finished_semaphore: vk.Semaphore,
in_flight_fence: vk.Fence,

time: f32,

pub fn init(allocator: std.mem.Allocator) !Renderer {
    const instance = try vk.Instance.init(.{
        .allocator = allocator,
        .extensions = Window.queryVkExtensions(),
    });
    errdefer instance.deinit();

    const window = try Window.init(.{ .instance = instance });
    errdefer window.deinit();

    const device = try vk.Device.init(instance, window);
    errdefer device.deinit();

    const graphics_pool = try vk.CommandPool.init(device, .Graphics);
    errdefer graphics_pool.deinit();

    const graphics_buffer = try graphics_pool.createCommandBuffer(.Primary);

    const bind_group_pool = try vk.BindGroupPool.init(device, .{
        .pool_sizes = &.{
            .{
                .type = .UniformBuffer,
                .count = 1,
            },
            .{
                .type = .CombinedImageSampler,
                .count = 1,
            },
        },
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const bind_group_layout = try vk.BindGroupLayout.init(device, .{
        .bindings = &.{
            .{
                .binding = 0,
                .type = .UniformBuffer,
                .stages = .{ .vertex = true },
            },
            .{
                .binding = 1,
                .type = .CombinedImageSampler,
                .stages = .{ .fragment = true },
            },
        },
    });
    errdefer bind_group_layout.deinit();

    const bind_group = try bind_group_pool.alloc(bind_group_layout);

    const uniform_buffer = try device.createBuffer(.{
        .size = 1024,
        .usage = .{ .uniform_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer uniform_buffer.deinit();

    const vertices: []const [3]f32 = &.{
        .{ 1.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 1.0 },
    };

    const indices: []const u16 = &.{ 0, 1, 2 };

    const vertex_buffer = try device.createBuffer(.{
        .size = 1024,
        .usage = .{ .vertex_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer vertex_buffer.deinit();

    const index_buffer = try device.createBuffer(.{
        .size = 1024,
        .usage = .{ .index_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer index_buffer.deinit();

    var staging_buffer = try vk.StagingBuffer.init(device, graphics_pool);
    errdefer staging_buffer.deinit();

    try staging_buffer.write(vertices);
    try staging_buffer.copyBuffer(.{ .dst = vertex_buffer, .size = 512 });

    try staging_buffer.write(indices);
    try staging_buffer.copyBuffer(.{ .dst = index_buffer, .size = 512 });

    const image = try vk.Image.init(device, .{
        .format = .R8G8B8A8Unorm,
        .extent = .{ .width = 2, .height = 2, .depth = 1 },
        .usage = .{ .transfer_dst = true, .sampled = true },
    });
    errdefer image.deinit();

    const view = try image.createView(.{
        .type = .Image2D,
        .format = .R8G8B8A8Unorm,
        .aspect = .{ .color = true },
    });
    errdefer view.deinit();

    const sampler = try vk.Sampler.init(device, .{});
    errdefer sampler.deinit();

    try staging_buffer.write(&[_]u8{ 255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255 });
    try staging_buffer.copyImage(.{
        .dst = image,
        .aspect = .{ .color = true },
        .old_layout = .Undefined,
        .extent = .{ .width = 2, .height = 2, .depth = 1 },
    });

    try device.updateBindGroups(.{
        .writes = &.{
            .{
                .dst = bind_group,
                .binding = 0,
                .resource = .{
                    .buffer = .{
                        .buffer = uniform_buffer,
                        .size = uniform_buffer.size,
                    },
                },
            },
            .{
                .dst = bind_group,
                .binding = 1,
                .resource = .{
                    .combined_image = .{
                        .sampler = sampler,
                        .view = view,
                        .layout = .ShaderReadOnlyOptimal,
                    },
                },
            },
        },
    });

    try graphics_buffer.begin(.{ .one_time_submit = true });

    try graphics_buffer.pipelineBarrier(.{
        .src_stage = .{ .top_of_pipe = true },
        .dst_stage = .{ .transfer = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{ .transfer_write = true },
                .old_layout = .TransferDstOptimal,
                .new_layout = .ShaderReadOnlyOptimal,
                .image = image,
                .aspect = .{ .color = true },
            },
        },
    });

    try graphics_buffer.end();

    try device.graphics.submit(.{
        .command_buffers = &.{
            graphics_buffer,
        },
    });

    try device.graphics.waitIdle();

    const format = try device.queryWindowFormat(window);
    const render_pass = try createRenderPass(device, format);
    errdefer render_pass.deinit();

    var swapchain = try vk.Swapchain.init(device, window, render_pass);
    errdefer swapchain.deinit();

    var pbr_pipeline = try createPbrPipeline(device, swapchain, bind_group_layout);
    errdefer pbr_pipeline.deinit();

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
        .render_pass = render_pass,
        .swapchain = swapchain,

        .pbr_pipeline = pbr_pipeline,

        .graphics_pool = graphics_pool,
        .graphics_buffer = graphics_buffer,

        .bind_pool = bind_group_pool,
        .bind_group_layout = bind_group_layout,
        .bind_group = bind_group,

        .staging_buffer = staging_buffer,
        .uniform_buffer = uniform_buffer,

        .image = image,
        .view = view,
        .sampler = sampler,

        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,

        .image_available_semaphore = image_available_semaphore,
        .render_finished_semaphore = render_finished_semaphore,
        .in_flight_fence = in_flight_fence,

        .time = 0.0,
    };
}

pub fn deinit(self: Renderer) void {
    self.device.waitIdle() catch {};

    self.in_flight_fence.deinit();
    self.render_finished_semaphore.deinit();
    self.image_available_semaphore.deinit();

    self.vertex_buffer.deinit();
    self.index_buffer.deinit();

    self.sampler.deinit();
    self.view.deinit();
    self.image.deinit();

    self.uniform_buffer.deinit();
    self.staging_buffer.deinit();

    self.bind_group_layout.deinit();
    self.bind_pool.deinit();

    self.graphics_pool.deinit();

    self.pbr_pipeline.deinit();

    self.swapchain.deinit();
    self.render_pass.deinit();
    self.device.deinit();
    self.window.deinit();
    self.instance.deinit();
}

fn recordCommandBuffer(self: *Renderer, image: u32) !void {
    try self.graphics_buffer.reset();
    try self.graphics_buffer.begin(.{});

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

    self.graphics_buffer.bindBindGroup(self.pbr_pipeline, 0, self.bind_group, &.{});

    self.graphics_buffer.setViewport(.{
        .width = @floatFromInt(self.swapchain.extent.width),
        .height = @floatFromInt(self.swapchain.extent.height),
    });

    self.graphics_buffer.setScissor(.{
        .width = self.swapchain.extent.width,
        .height = self.swapchain.extent.height,
    });

    self.graphics_buffer.bindVertexBuffer(0, self.vertex_buffer, 0);
    self.graphics_buffer.bindIndexBuffer(self.index_buffer, 0, .u16);

    self.graphics_buffer.drawIndexed(.{ .index_count = 3 });

    self.graphics_buffer.endRenderPass();

    try self.graphics_buffer.end();
}

pub fn tryDrawFrame(self: *Renderer) !void {
    try self.in_flight_fence.wait(.{});
    try self.in_flight_fence.reset();

    const image = try self.swapchain.aquireNextImage(.{
        .semaphore = self.image_available_semaphore,
    });

    self.time += 0.01;
    try self.staging_buffer.write(&@as(f32, self.time));
    try self.staging_buffer.copyBuffer(.{ .dst = self.uniform_buffer, .size = 4 });

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
        error.VK_SUBOPTIMAL_KHR => return try self.swapchain.recreate(),
        error.VK_ERROR_OUT_OF_DATE_KHR => return try self.swapchain.recreate(),
        else => return err,
    };
}
