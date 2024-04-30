const std = @import("std");
const vk = @import("vulkan");

const asset = @import("../asset.zig");
const system = @import("../system.zig");
const material = @import("material.zig");

const Game = @import("../Game.zig");
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

    const device = try vk.Device.init(.{
        .instance = instance,
        .compatible_surface = window.surface,
    });
    errdefer device.deinit();

    const sdr = try Sdr.init(
        allocator,
        device,
        window.surface,
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

    if (!game.world.containsResource(asset.Assets(Mesh))) {
        const meshes = asset.Assets(Mesh).init(allocator);
        try game.world.addResource(meshes);
    }

    const camera_system = try game.addSystem(Camera.Prepared.system);
    try camera_system.after(Game.Phase.Update);
    try camera_system.before(Game.Phase.Render);

    const transform_system = try game.addSystem(PreparedTransform.system);
    try transform_system.after(Game.Phase.Update);
    try transform_system.before(Game.Phase.Render);

    const mesh_system = try game.addSystem(PreparedMeshes.system);
    try mesh_system.after(Game.Phase.Update);
    try mesh_system.before(Game.Phase.Render);

    const render_system = try game.addSystem(renderSystem);
    try render_system.after(Game.Phase.Update);
    try render_system.label(Game.Phase.Render);
}

fn recreate(
    device: *vk.Device,
    hdr: *Hdr,
    sdr: *Sdr,
    tonemap: *Tonemap,
    prepared_light: *PreparedLight,
) !void {
    try device.waitIdle();

    try sdr.recreate();
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
    device: *vk.Device,
    draw_commands: *DrawCommand.Queue,
    hdr: *Hdr,
    sdr: *Sdr,
    sky: *Sky,
    tonemap: *Tonemap,
    light: *PreparedLight,
    present: *Present,
    camera_query: Query(struct {
        prepared_camera: *Camera.Prepared,
    }),
) !void {
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
            tonemap,
            light,
        ),
        else => return err,
    };
}
