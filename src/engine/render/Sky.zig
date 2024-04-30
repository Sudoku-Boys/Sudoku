const std = @import("std");
const vk = @import("vulkan");

const Camera = @import("Camera.zig");
const Hdr = @import("Hdr.zig");

const Sky = @This();

graphics_pipeline: vk.GraphicsPipeline,

pub fn init(
    device: vk.Device,
    camera_pipeline: Camera.Pipeline,
    render_pass: vk.RenderPass,
    subpass: u32,
) !Sky {
    const graphics_pipeline = try createRenderPipeline(
        device,
        camera_pipeline,
        render_pass,
        subpass,
    );
    errdefer graphics_pipeline.deinit();

    return .{
        .graphics_pipeline = graphics_pipeline,
    };
}

pub fn deinit(self: Sky) void {
    self.graphics_pipeline.deinit();
}

fn createRenderPipeline(
    device: vk.Device,
    camera_pipeline: Camera.Pipeline,
    render_pass: vk.RenderPass,
    subpass: u32,
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
        .layouts = &.{
            null,
            null,
            camera_pipeline.layout,
        },
        .render_pass = render_pass,
        .subpass = subpass,
    });
}

pub fn record(self: Sky, command_buffer: vk.CommandBuffer, camera: Camera.Prepared) void {
    command_buffer.bindGraphicsPipeline(self.graphics_pipeline);
    command_buffer.bindBindGroup(self.graphics_pipeline, 2, camera.bind_group, &.{});

    command_buffer.draw(.{ .vertex_count = 6 });
}
