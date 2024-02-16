const std = @import("std");
const vk = @import("vulkan");

const CameraState = @import("CameraState.zig");
const Material = @import("Material.zig");
const Renderer = @import("Renderer.zig");

const Sky = @This();

render_pass: vk.RenderPass,
graphics_pipeline: vk.GraphicsPipeline,

framebuffer: vk.Framebuffer,
view: vk.ImageView,

pub fn init(
    device: vk.Device,
    layouts: Material.BindGroupLayouts,
    target: vk.Image,
) !Sky {
    const render_pass = try createRenderPass(device);
    errdefer render_pass.deinit();

    const graphics_pipeline = try createRenderPipeline(device, layouts.camera, render_pass);
    errdefer graphics_pipeline.deinit();

    const view = try createView(target);
    errdefer view.deinit();

    const framebuffer = try createFramebuffer(render_pass, view);
    errdefer framebuffer.deinit();

    return .{
        .render_pass = render_pass,
        .graphics_pipeline = graphics_pipeline,

        .framebuffer = framebuffer,
        .view = view,
    };
}

pub fn deinit(self: Sky) void {
    self.graphics_pipeline.deinit();
    self.render_pass.deinit();

    self.framebuffer.deinit();
    self.view.deinit();
}

pub fn setTarget(self: *Sky, target: vk.Image) !void {
    self.view.deinit();
    self.view = try createView(target);

    self.framebuffer.deinit();
    self.framebuffer = try createFramebuffer(self.render_pass, self.view);
}

fn createRenderPass(
    device: vk.Device,
) !vk.RenderPass {
    return try device.createRenderPass(.{
        .attachments = &.{
            .{
                .format = Renderer.Hdr.COLOR_FORMAT,
                .samples = 1,
                .load_op = .Clear,
                .store_op = .Store,
                .final_layout = .ColorAttachmentOptimal,
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

fn createRenderPipeline(
    device: vk.Device,
    layout: vk.BindGroupLayout,
    render_pass: vk.RenderPass,
) !vk.GraphicsPipeline {
    return device.createGraphicsPipeline(.{
        .vertex = .{
            .shader = vk.embedSpirv(@embedFile("shaders/fullscreen.vert")),
            .entry_point = "main",
        },
        .fragment = .{
            .shader = vk.embedSpirv(@embedFile("shaders/sky.frag")),
            .entry_point = "main",
        },
        .color_blend = .{
            .attachments = &.{
                .{},
            },
        },
        .layouts = &.{ null, null, layout },
        .render_pass = render_pass,
        .subpass = 0,
    });
}

fn createView(image: vk.Image) !vk.ImageView {
    return try image.createView(.{
        .aspect = .{ .color = true },
    });
}

fn createFramebuffer(render_pass: vk.RenderPass, view: vk.ImageView) !vk.Framebuffer {
    return try render_pass.createFramebuffer(
        .{
            .attachments = &.{view},
            .extent = view.extent.as2D(),
        },
    );
}

pub fn record(self: Sky, command_buffer: vk.CommandBuffer, camera_state: CameraState) void {
    command_buffer.beginRenderPass(.{
        .render_pass = self.render_pass,
        .framebuffer = self.framebuffer,
        .render_area = .{
            .extent = self.view.extent.as2D(),
        },
    });

    command_buffer.bindGraphicsPipeline(self.graphics_pipeline);
    command_buffer.bindBindGroup(self.graphics_pipeline, 2, camera_state.bind_group, &.{});

    command_buffer.draw(.{ .vertex_count = 6 });

    command_buffer.endRenderPass();
}
