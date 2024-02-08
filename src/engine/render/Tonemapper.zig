const std = @import("std");
const vk = @import("vulkan");

const Tonemapper = @This();

graphics_pipeline: vk.GraphicsPipeline,

bind_group_pool: vk.BindGroupPool,
bind_group_layout: vk.BindGroupLayout,
bind_group: vk.BindGroup,

sampler: vk.Sampler,

pub fn init(
    device: vk.Device,
    render_pass: vk.RenderPass,
    subpass: u32,
) !Tonemapper {
    const bind_group_pool = try device.createBindGroupPool(.{
        .pool_sizes = &.{
            .{
                .type = .CombinedImageSampler,
                .count = 1,
            },
        },
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const bind_group_layout = try device.createBindGroupLayout(.{
        .entries = &.{
            .{
                .binding = 0,
                .type = .CombinedImageSampler,
                .stages = .{ .fragment = true },
            },
        },
    });
    errdefer bind_group_layout.deinit();

    const bind_group = try bind_group_pool.alloc(bind_group_layout);

    const sampler = try device.createSampler(.{});
    errdefer sampler.deinit();

    const graphics_pipeline = try createRenderPipeline(
        device,
        bind_group_layout,
        render_pass,
        subpass,
    );

    return .{
        .graphics_pipeline = graphics_pipeline,
        .bind_group_pool = bind_group_pool,
        .bind_group_layout = bind_group_layout,
        .bind_group = bind_group,
        .sampler = sampler,
    };
}

pub fn deinit(self: Tonemapper) void {
    self.sampler.deinit();

    self.bind_group_layout.deinit();
    self.bind_group_pool.deinit();

    self.graphics_pipeline.deinit();
}

fn createRenderPipeline(
    device: vk.Device,
    bind_group_layout: vk.BindGroupLayout,
    render_pass: vk.RenderPass,
    subpass: u32,
) !vk.GraphicsPipeline {
    return device.createGraphicsPipeline(.{
        .vertex = .{
            .shader = vk.embedSpirv(@embedFile("shader/fullscreen.vert")),
            .entry_point = "main",
        },
        .fragment = .{
            .shader = vk.embedSpirv(@embedFile("shader/tonemapper.frag")),
            .entry_point = "main",
        },
        .color_blend = .{
            .attachments = &.{
                .{},
            },
        },
        .layouts = &.{bind_group_layout},
        .render_pass = render_pass,
        .subpass = subpass,
    });
}

pub fn setHdrImage(self: Tonemapper, device: vk.Device, hdr_image: vk.ImageView) !void {
    device.updateBindGroups(.{
        .writes = &.{
            .{
                .dst = self.bind_group,
                .binding = 0,
                .resource = .{
                    .combined_image = .{
                        .sampler = self.sampler,
                        .view = hdr_image,
                        .layout = .ShaderReadOnlyOptimal,
                    },
                },
            },
        },
    });
}

pub fn recordCommandBuffer(self: Tonemapper, command_buffer: vk.CommandBuffer) !void {
    command_buffer.bindGraphicsPipeline(self.graphics_pipeline);
    command_buffer.bindBindGroup(self.graphics_pipeline, 0, self.bind_group, &.{});

    command_buffer.draw(.{ .vertex_count = 6 });
}
