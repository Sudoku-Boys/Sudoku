const std = @import("std");
const vk = @import("vulkan");

const asset = @import("../asset.zig");
const hirachy = @import("../hirachy.zig");
const system = @import("../system.zig");
const material = @import("material.zig");
const event = @import("../event.zig");

const Game = @import("../Game.zig");
const Image = @import("../Image.zig");
const Window = @import("../Window.zig");
const Query = @import("../query.zig").Query;

const Camera = @import("Camera.zig");
const DrawCommand = @import("DrawCommand.zig");
const Hdr = @import("Hdr.zig");
const Mesh = @import("Mesh.zig");
const Present = @import("Present.zig");
const PreparedLight = @import("PreparedLight.zig");
const PreparedTransform = @import("PreparedTransform.zig");
const PreparedMeshes = @import("PreparedMeshes.zig");
const PreparedImage = @import("PreparedImage.zig");
const Sdr = @import("Sdr.zig");
const Sky = @import("Sky.zig");
const Tonemap = @import("Tonemap.zig");

const RenderPlugin = @This();

pub const Phase = enum {
    Present,
};

pub const CommandPools = struct {
    graphics: vk.CommandPool,
    present: vk.CommandPool,

    pub fn deinit(self: CommandPools) void {
        self.graphics.deinit();
        self.present.deinit();
    }
};

present_mode: vk.PresentMode = .Fifo,

pub fn buildPlugin(self: RenderPlugin, game: *Game) !void {
    const allocator = game.world.allocator;

    const instance = try vk.Instance.init(.{
        .allocator = allocator,
        .required_extensions = Window.requiredVulkanExtensions(),
    });
    errdefer instance.deinit();

    const window = try Window.init(.{
        .instance = instance,
    });
    errdefer window.deinit();

    const window_state = Window.State{};

    const device = try vk.Device.init(.{
        .instance = instance,
        .compatible_surface = window.surface,
    });
    errdefer device.deinit();

    const sdr = try Sdr.init(
        allocator,
        device,
        window.surface,
        window.getSize(),
        self.present_mode,
    );
    errdefer sdr.deinit();

    const hdr = try Hdr.init(device, sdr.swapchain.extent);
    errdefer hdr.deinit();

    const graphics_pool = try device.createCommandPool(.Graphics);
    errdefer graphics_pool.deinit();

    const present_pool = try device.createCommandPool(.Present);
    errdefer present_pool.deinit();

    const pools = CommandPools{
        .graphics = graphics_pool,
        .present = present_pool,
    };

    const present = try Present.init(device, graphics_pool);
    errdefer present.deinit();

    const staging_buffer = try vk.StagingBuffer.init(device, pools.graphics);
    errdefer staging_buffer.deinit();

    const camera_pipeline = try Camera.Pipeline.init(device);
    errdefer camera_pipeline.deinit();

    const transform_pipeline = try PreparedTransform.Pipeline.init(device);
    errdefer transform_pipeline.deinit();

    const sky = try Sky.init(device, camera_pipeline, hdr.render_pass, 0);
    errdefer sky.deinit();

    var prepared_meshes = PreparedMeshes.init(allocator);
    errdefer prepared_meshes.deinit();

    const prepared_light = try PreparedLight.init(device, hdr.color_image);
    errdefer prepared_light.deinit();

    const tonemap = try Tonemap.init(device, sdr.render_pass, 0);
    errdefer tonemap.deinit();

    tonemap.setHdrImage(device, hdr.color_view);

    var draw_commands = DrawCommand.Queue.init(allocator);
    errdefer draw_commands.deinit();

    try game.world.addResource(instance);
    try game.world.addResource(window);
    try game.world.addResource(window_state);
    try game.world.addResource(device);
    try game.world.addResource(sdr);
    try game.world.addResource(hdr);
    try game.world.addResource(pools);
    try game.world.addResource(present);
    try game.world.addResource(staging_buffer);
    try game.world.addResource(camera_pipeline);
    try game.world.addResource(transform_pipeline);
    try game.world.addResource(sky);
    try game.world.addResource(prepared_meshes);
    try game.world.addResource(prepared_light);
    try game.world.addResource(tonemap);
    try game.world.addResource(draw_commands);

    try game.addAsset(Mesh);
    try game.addAsset(Image);
    try game.addAsset(PreparedImage);

    try game.addEvent(Window.MouseMoved);
    try game.addEvent(Window.SizeChanged);

    const window_system = try game.addSystem(Window.eventSystem);
    window_system.name("Window Event System");
    window_system.before(Game.Phase.Start);

    const camera_system = try game.addSystem(Camera.Prepared.system);
    camera_system.name("Prepare Camera System");
    camera_system.after(Game.Phase.Update);
    camera_system.before(Game.Phase.Render);

    const transform_system = try game.addSystem(PreparedTransform.system);
    transform_system.name("Prepare Transform System");
    transform_system.after(hirachy.HirachyPhase.Transform);
    transform_system.before(Game.Phase.Render);

    const mesh_system = try game.addSystem(PreparedMeshes.system);
    mesh_system.name("Prepare Mesh System");
    mesh_system.after(Game.Phase.Update);
    mesh_system.before(Game.Phase.Render);

    const image_system = try game.addSystem(PreparedImage.system);
    image_system.name("Prepare Image System");
    image_system.after(Game.Phase.Update);
    image_system.before(Game.Phase.Render);

    const render_system = try game.addSystem(renderSystem);
    render_system.name("Render System");
    render_system.after(Game.Phase.Update);
    render_system.label(Game.Phase.Render);
}

fn recreate(
    device: *vk.Device,
    hdr: *Hdr,
    sdr: *Sdr,
    window: *Window,
    tonemap: *Tonemap,
    prepared_light: *PreparedLight,
) !void {
    try device.waitIdle();

    try sdr.recreate(window.getSize());
    try hdr.recreate(device.*, sdr.swapchain.extent);

    tonemap.setHdrImage(device.*, hdr.color_view);

    try prepared_light.setTarget(device.*, hdr.color_image);
}

fn recordCommandBuffer(
    device: *vk.Device,
    draw_commands: *DrawCommand.Queue,
    hdr: *Hdr,
    sdr: *Sdr,
    sky: *Sky,
    tonemap: *Tonemap,
    camera: Camera.Prepared,
    light: *PreparedLight,
    present: *Present,
    image_index: u32,
) !void {
    _ = device;

    try present.graphics_buffer.reset();
    try present.graphics_buffer.begin(.{});

    present.graphics_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .Undefined,
                .new_layout = .ShaderReadOnlyOptimal,
                .image = light.transmission_image,
                .aspect = .{ .color = true },
                .level_count = light.transmission_image.mip_levels,
            },
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .ShaderReadOnlyOptimal,
                .new_layout = .ColorAttachmentOptimal,
                .image = hdr.color_image,
                .aspect = .{ .color = true },
            },
        },
    });

    present.graphics_buffer.setViewport(.{
        .width = @floatFromInt(sdr.swapchain.extent.width),
        .height = @floatFromInt(sdr.swapchain.extent.height),
    });

    present.graphics_buffer.setScissor(.{
        .extent = sdr.swapchain.extent.as2D(),
    });

    // ---------- HDR ----------

    present.graphics_buffer.beginRenderPass(.{
        .render_pass = hdr.render_pass,
        .framebuffer = hdr.framebuffer,
        .render_area = .{
            .extent = hdr.color_image.extent.as2D(),
        },
    });

    sky.record(present.graphics_buffer, camera);

    for (draw_commands.commands.items) |command| {
        present.graphics_buffer.bindGraphicsPipeline(command.pipeline);

        for (command.bind_groups, 0..) |bind_group, i| {
            present.graphics_buffer.bindBindGroup(
                command.pipeline,
                @intCast(i),
                bind_group,
                &.{},
            );
        }

        for (command.vertex_buffers, 0..) |buffer, i| {
            present.graphics_buffer.bindVertexBuffer(
                @intCast(i),
                buffer,
                0,
            );
        }

        present.graphics_buffer.bindIndexBuffer(command.index_buffer, 0, .u32);

        present.graphics_buffer.drawIndexed(.{
            .index_count = command.index_count,
        });
    }

    draw_commands.clear();

    present.graphics_buffer.endRenderPass();

    // ---------- SDR ----------

    present.graphics_buffer.beginRenderPass(.{
        .render_pass = sdr.render_pass,
        .framebuffer = sdr.framebuffers[image_index],
        .render_area = .{
            .extent = sdr.swapchain.extent.as2D(),
        },
    });

    try tonemap.recordCommandBuffer(present.graphics_buffer);

    present.graphics_buffer.endRenderPass();

    try present.graphics_buffer.end();
}

pub fn renderSystem(
    size_changed: event.EventReader(Window.SizeChanged),
    device: *vk.Device,
    draw_commands: *DrawCommand.Queue,
    hdr: *Hdr,
    sdr: *Sdr,
    sky: *Sky,
    window: *Window,
    tonemap: *Tonemap,
    light: *PreparedLight,
    present: *Present,
    camera_query: Query(struct {
        prepared_camera: *Camera.Prepared,
    }),
) !void {
    // recreate when the window size changes
    while (size_changed.next()) |_| {
        try recreate(
            device,
            hdr,
            sdr,
            window,
            tonemap,
            light,
        );
    }

    try present.in_flight.wait(.{});

    const image_index = sdr.swapchain.acquireNextImage(.{
        .semaphore = present.image_available,
    }) catch |err| switch (err) {
        error.VK_SUBOPTIMAL_KHR,
        error.VK_ERROR_OUT_OF_DATE_KHR,
        => return try recreate(
            device,
            hdr,
            sdr,
            window,
            tonemap,
            light,
        ),
        else => return err,
    };

    try present.in_flight.reset();

    var camera_it = camera_query.iterator();
    const camera = camera_it.next().?;

    try recordCommandBuffer(
        device,
        draw_commands,
        hdr,
        sdr,
        sky,
        tonemap,
        camera.prepared_camera.*,
        light,
        present,
        image_index,
    );

    try device.graphics.submit(.{
        .wait_semaphores = &.{
            .{
                .semaphore = present.image_available,
                .stage = .{ .color_attachment_output = true },
            },
        },
        .command_buffers = &.{
            present.graphics_buffer,
        },
        .signal_semaphores = &.{
            present.render_finished,
        },
        .fence = present.in_flight,
    });

    device.present.present(.{
        .swapchains = &.{
            .{
                .swapchain = sdr.swapchain,
                .image_index = image_index,
            },
        },
        .wait_semaphores = &.{
            present.render_finished,
        },
    }) catch |err| switch (err) {
        error.VK_SUBOPTIMAL_KHR,
        error.VK_ERROR_OUT_OF_DATE_KHR,
        => return try recreate(
            device,
            hdr,
            sdr,
            window,
            tonemap,
            light,
        ),
        else => return err,
    };
}
