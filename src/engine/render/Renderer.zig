const std = @import("std");
const vk = @import("vulkan");

const asset = @import("../asset.zig");
const Materials = @import("Materials.zig");
const Mesh = @import("Mesh.zig");
const Tonemap = @import("Tonemap.zig");
const Scene = @import("Scene.zig");
const SceneRenderer = @import("SceneRenderer.zig");

const Renderer = @This();

pub const Hdr = struct {
    color_image: vk.Image,
    color_view: vk.ImageView,

    pub const COLOR_FORMAT = vk.ImageFormat.R16G16B16A16Sfloat;

    fn init(device: vk.Device, extent: vk.Extent3D) !Hdr {
        const color_image = try createColorImage(device, extent);
        errdefer color_image.deinit();

        const color_view = try color_image.createView(.{
            .format = COLOR_FORMAT,
            .aspect = .{ .color = true },
        });
        errdefer color_view.deinit();

        return .{
            .color_image = color_image,
            .color_view = color_view,
        };
    }

    fn deinit(self: Hdr) void {
        self.color_view.deinit();
        self.color_image.deinit();
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

    fn recreate(self: *Hdr, device: vk.Device, extent: vk.Extent3D) !void {
        self.color_image.deinit();
        self.color_image = try createColorImage(device, extent);

        self.color_view.deinit();
        self.color_view = try self.color_image.createView(.{
            .format = Hdr.COLOR_FORMAT,
            .aspect = .{ .color = true },
        });
    }
};

pub const Sdr = struct {
    swapchain: vk.Swapchain,
    render_pass: vk.RenderPass,
    framebuffers: []vk.Framebuffer,

    const COLOR_FORMAT: vk.ImageFormat = vk.ImageFormat.B8G8R8A8Unorm;

    fn init(
        allocator: std.mem.Allocator,
        device: vk.Device,
        surface: vk.Surface,
        present_mode: vk.PresentMode,
    ) !Sdr {
        const render_pass = try createRenderPass(device);
        const swapchain = try device.createSwapchain(.{
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
            .swapchain = swapchain,
            .render_pass = render_pass,
            .framebuffers = framebuffers,
        };
    }

    fn deinit(self: Sdr, allocator: std.mem.Allocator) void {
        for (self.framebuffers) |framebuffer| {
            framebuffer.deinit();
        }

        allocator.free(self.framebuffers);

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

    fn recreate(self: *Sdr, allocator: std.mem.Allocator) !void {
        for (self.framebuffers) |framebuffer| {
            framebuffer.deinit();
        }

        try self.swapchain.recreate();

        self.framebuffers = try allocator.realloc(self.framebuffers, self.swapchain.images.len);

        for (self.swapchain.views, 0..) |view, i| {
            self.framebuffers[i] = try self.render_pass.createFramebuffer(.{
                .attachments = &.{view},
                .extent = self.swapchain.extent.as2D(),
            });
        }
    }
};

allocator: std.mem.Allocator,
device: vk.Device,
surface: vk.Surface,

sdr: Sdr,
hdr: Hdr,

graphics_pool: vk.CommandPool,
graphics_buffer: vk.CommandBuffer,

scene_renderer: SceneRenderer,

tonemap: Tonemap,

in_flight: vk.Fence,
image_available: vk.Semaphore,
render_finished: vk.Semaphore,

pub const Descriptor = struct {
    allocator: std.mem.Allocator,
    device: vk.Device,
    surface: vk.Surface,
    present_mode: vk.PresentMode = .Fifo,
};

pub fn init(desc: Descriptor) !Renderer {
    const sdr = try Sdr.init(
        desc.allocator,
        desc.device,
        desc.surface,
        desc.present_mode,
    );
    errdefer sdr.deinit(desc.allocator);

    const hdr = try Hdr.init(desc.device, sdr.swapchain.extent);
    errdefer hdr.deinit();

    const graphics_pool = try desc.device.createCommandPool(.Graphics);
    errdefer graphics_pool.deinit();

    const graphics_buffer = try graphics_pool.alloc(.Primary);

    var scene_renderer = try SceneRenderer.init(
        desc.allocator,
        desc.device,
        graphics_pool,
        hdr.color_image,
    );
    errdefer scene_renderer.deinit();

    const in_flight = try desc.device.createFence(true);
    errdefer in_flight.deinit();

    const image_available = try desc.device.createSemaphore();
    errdefer image_available.deinit();

    const render_finished = try desc.device.createSemaphore();
    errdefer render_finished.deinit();

    const tonemap = try Tonemap.init(desc.device, sdr.render_pass, 0);
    try tonemap.setHdrImage(desc.device, hdr.color_view);

    return .{
        .allocator = desc.allocator,
        .device = desc.device,
        .surface = desc.surface,

        .sdr = sdr,
        .hdr = hdr,

        .graphics_pool = graphics_pool,
        .graphics_buffer = graphics_buffer,

        .scene_renderer = scene_renderer,

        .tonemap = tonemap,

        .in_flight = in_flight,
        .image_available = image_available,
        .render_finished = render_finished,
    };
}

pub fn deinit(self: *Renderer) void {
    // very important as it turns out
    self.device.waitIdle() catch {};

    self.render_finished.deinit();
    self.image_available.deinit();
    self.in_flight.deinit();

    self.tonemap.deinit();

    self.scene_renderer.deinit();

    self.graphics_pool.deinit();

    self.hdr.deinit();
    self.sdr.deinit(self.allocator);
}

pub fn addMaterial(self: *Renderer, comptime T: type) !void {
    try self.scene_renderer.addMaterial(T, self.device);
}

fn recordCommandBuffer(
    self: *Renderer,
    scene: Scene,
    image_index: usize,
) !void {
    try self.graphics_buffer.reset();
    try self.graphics_buffer.begin(.{});

    self.graphics_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .Undefined,
                .new_layout = .ColorAttachmentOptimal,
                .image = self.hdr.color_image,
                .aspect = .{ .color = true },
            },
        },
    });

    // ---------- HDR ----------

    self.graphics_buffer.setViewport(.{
        .width = @floatFromInt(self.sdr.swapchain.extent.width),
        .height = @floatFromInt(self.sdr.swapchain.extent.height),
    });

    self.graphics_buffer.setScissor(.{
        .extent = self.sdr.swapchain.extent.as2D(),
    });

    try self.scene_renderer.draw(self.graphics_buffer, scene);

    // ---------- SDR ----------

    self.graphics_buffer.beginRenderPass(.{
        .render_pass = self.sdr.render_pass,
        .framebuffer = self.sdr.framebuffers[image_index],
        .render_area = .{
            .extent = self.sdr.swapchain.extent.as2D(),
        },
    });

    try self.tonemap.recordCommandBuffer(self.graphics_buffer);

    self.graphics_buffer.endRenderPass();

    try self.graphics_buffer.end();
}

fn recreate(self: *Renderer) !void {
    try self.device.waitIdle();

    try self.sdr.recreate(self.allocator);
    try self.hdr.recreate(self.device, self.sdr.swapchain.extent);
    try self.tonemap.setHdrImage(self.device, self.hdr.color_view);

    try self.scene_renderer.setTarget(self.device, self.hdr.color_image);
}

pub fn drawFrame(
    self: *Renderer,
    meshes: asset.Assets(Mesh),
    materials: Materials,
    scene: Scene,
) !void {
    try self.scene_renderer.prepare(self.device, meshes, materials, scene);

    try self.in_flight.wait(.{});

    const image_index = self.sdr.swapchain.acquireNextImage(.{
        .semaphore = self.image_available,
    }) catch |err| switch (err) {
        error.VK_SUBOPTIMAL_KHR,
        error.VK_ERROR_OUT_OF_DATE_KHR,
        => return try self.recreate(),
        else => return err,
    };

    try self.in_flight.reset();

    try self.recordCommandBuffer(scene, image_index);

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

    self.device.present.present(.{
        .swapchains = &.{
            .{
                .swapchain = self.sdr.swapchain,
                .image_index = image_index,
            },
        },
        .wait_semaphores = &.{
            self.render_finished,
        },
    }) catch |err| switch (err) {
        error.VK_SUBOPTIMAL_KHR,
        error.VK_ERROR_OUT_OF_DATE_KHR,
        => return try self.recreate(),
        else => return err,
    };
}
