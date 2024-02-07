const std = @import("std");
const vk = @import("vulkan");
const Color = @import("../Color.zig");
const Mesh = @import("Mesh.zig");
const math = @import("../../math.zig");

const StandardMaterial = @This();

color: Color = Color.WHITE,

pub const Uniforms = extern struct {
    model: math.Mat4,
};

pub const PipelineState = struct {
    bind_group_layout: vk.BindGroupLayout,
    graphics_pipeline: vk.GraphicsPipeline,

    pub fn init(
        device: vk.Device,
        camera_bind_group_layout: vk.BindGroupLayout,
        render_pass: vk.RenderPass,
        subpass: u32,
    ) !PipelineState {
        const bind_group_layout = try createBindGroupLayout(device);
        errdefer bind_group_layout.deinit();

        const graphics_pipeline = try createGraphicsPipeline(
            device,
            camera_bind_group_layout,
            bind_group_layout,
            render_pass,
            subpass,
        );

        return PipelineState{
            .bind_group_layout = bind_group_layout,
            .graphics_pipeline = graphics_pipeline,
        };
    }

    pub fn deinit(self: PipelineState) void {
        self.graphics_pipeline.deinit();
        self.bind_group_layout.deinit();
    }
};

pub const InstanceState = struct {
    vertex_buffer: vk.Buffer,
    index_buffer: vk.Buffer,
    uniform_buffer: vk.Buffer,
    bind_group_pool: vk.BindGroupPool,
    bind_group: vk.BindGroup,

    pub fn init(
        device: vk.Device,
        pipeline_state: PipelineState,
        staging_buffer: *vk.StagingBuffer,
        mesh: Mesh,
    ) !InstanceState {
        const vertex_buffer = try device.createBuffer(.{
            .size = mesh.vertices.len * @sizeOf(Mesh.Vertex),
            .usage = .{ .vertex_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });
        errdefer vertex_buffer.deinit();

        const index_buffer = try device.createBuffer(.{
            .size = mesh.indices.len * @sizeOf(u32),
            .usage = .{ .index_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });
        errdefer index_buffer.deinit();

        const uniform_buffer = try device.createBuffer(.{
            .size = @sizeOf(Uniforms),
            .usage = .{ .uniform_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });
        errdefer uniform_buffer.deinit();

        try staging_buffer.write(mesh.vertexBytes());
        try staging_buffer.copyBuffer(.{
            .dst = vertex_buffer,
            .size = mesh.vertices.len * @sizeOf(Mesh.Vertex),
        });

        try staging_buffer.write(mesh.indexBytes());
        try staging_buffer.copyBuffer(.{
            .dst = index_buffer,
            .size = mesh.indices.len * @sizeOf(u32),
        });

        const bind_group_pool = try device.createBindGroupPool(.{
            .pool_sizes = &.{
                .{
                    .type = .UniformBuffer,
                    .count = 1,
                },
            },
            .max_groups = 1,
        });
        errdefer bind_group_pool.deinit();

        const bind_group = try bind_group_pool.alloc(pipeline_state.bind_group_layout);

        try device.updateBindGroups(.{
            .writes = &.{
                .{
                    .dst = bind_group,
                    .binding = 0,
                    .resource = .{
                        .buffer = .{
                            .buffer = uniform_buffer,
                            .size = @sizeOf(Uniforms),
                        },
                    },
                },
            },
        });

        return InstanceState{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .uniform_buffer = uniform_buffer,
            .bind_group_pool = bind_group_pool,
            .bind_group = bind_group,
        };
    }

    pub fn deinit(self: InstanceState) void {
        self.bind_group_pool.deinit();
        self.uniform_buffer.deinit();
        self.index_buffer.deinit();
        self.vertex_buffer.deinit();
    }
};

fn createBindGroupLayout(device: vk.Device) !vk.BindGroupLayout {
    return vk.BindGroupLayout.init(device, .{
        .bindings = &.{
            .{
                .binding = 0,
                .type = .UniformBuffer,
                .stages = .{ .vertex = true },
            },
        },
    });
}

fn createGraphicsPipeline(
    device: vk.Device,
    camera_bind_group_layout: vk.BindGroupLayout,
    material_bind_group_layout: vk.BindGroupLayout,
    render_pass: vk.RenderPass,
    subpass: u32,
) !vk.GraphicsPipeline {
    return device.createGraphicsPipeline(.{
        .vertex = .{
            .shader = vk.embedSpv(@embedFile("shader/standard_material.vert")),
            .entry_point = "main",
            .bindings = &.{
                .{
                    .binding = 0,
                    .stride = @sizeOf(Mesh.Vertex),
                    .attributes = Mesh.Vertex.ATTRIBUTES,
                },
            },
        },
        .fragment = .{
            .shader = vk.embedSpv(@embedFile("shader/standard_material.frag")),
            .entry_point = "main",
        },
        .depth_stencil = .{
            .depth_test_enable = true,
            .depth_write_enable = true,
        },
        .color_blend = .{
            .attachments = &.{
                .{},
            },
        },
        .layouts = &.{
            camera_bind_group_layout,
            material_bind_group_layout,
        },
        .render_pass = render_pass,
        .subpass = subpass,
    });
}

pub fn prepareInstance(
    device: vk.Device,
    instance_state: *InstanceState,
    staging_buffer: *vk.StagingBuffer,
    model: math.Mat4,
) !void {
    _ = device;

    const uniforms = Uniforms{
        .model = model,
    };

    try staging_buffer.write(&uniforms);
    try staging_buffer.copyBuffer(.{
        .dst = instance_state.uniform_buffer,
        .size = @sizeOf(Uniforms),
    });
}

pub fn recordInstance(
    command_buffer: vk.CommandBuffer,
    pipeline_state: PipelineState,
    instance_state: InstanceState,
    camera_bind_group: vk.BindGroup,
    mesh: Mesh,
) !void {
    command_buffer.bindGraphicsPipeline(pipeline_state.graphics_pipeline);
    command_buffer.bindBindGroup(pipeline_state.graphics_pipeline, 0, camera_bind_group, &.{});
    command_buffer.bindBindGroup(pipeline_state.graphics_pipeline, 1, instance_state.bind_group, &.{});

    command_buffer.bindVertexBuffer(0, instance_state.vertex_buffer, 0);
    command_buffer.bindIndexBuffer(instance_state.index_buffer, 0, .u32);

    command_buffer.drawIndexed(.{
        .index_count = @intCast(mesh.indices.len),
    });
}
