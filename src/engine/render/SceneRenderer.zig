const std = @import("std");
const vk = @import("vulkan");

const Camera = @import("Camera.zig");
const CameraState = @import("CameraState.zig");
const LightState = @import("LightState.zig");
const Material = @import("Material.zig");
const Materials = @import("Materials.zig");
const MaterialState = @import("MaterialState.zig");
const Mesh = @import("Mesh.zig");
const Meshes = @import("Meshes.zig");
const Object = @import("Object.zig");
const OpaqueMaterial = @import("OpaqueMaterial.zig");
const Renderer = @import("Renderer.zig");
const Scene = @import("Scene.zig");
const Sky = @import("Sky.zig");
const math = @import("../math.zig");

const TypeId = std.builtin.TypeId;

const SceneRenderer = @This();

const ModelUniforms = extern struct {
    model: math.Mat4,
};

const ObjectState = struct {
    bind_group_pool: vk.BindGroupPool,
    bind_group: vk.BindGroup,
    model_buffer: vk.Buffer,

    pub fn deinit(self: ObjectState) void {
        self.bind_group_pool.deinit();
        self.model_buffer.deinit();
    }
};

const VertexBuffer = struct {
    name: []const u8,
    buffer: vk.Buffer,
};

const MeshState = struct {
    vertex_buffers: []const VertexBuffer,
    index_buffer: vk.Buffer,
    index_count: u32,
    generation: u64,
    version: u64,

    pub fn deinit(self: MeshState, allocator: std.mem.Allocator) void {
        for (self.vertex_buffers) |buffer| {
            buffer.buffer.deinit();
        }

        allocator.free(self.vertex_buffers);
        self.index_buffer.deinit();
    }

    fn getBuffer(self: MeshState, name: []const u8) ?vk.Buffer {
        for (self.vertex_buffers) |buffer| {
            if (std.mem.eql(u8, buffer.name, name)) return buffer.buffer;
        }

        return null;
    }
};

allocator: std.mem.Allocator,

layouts: Material.BindGroupLayouts,
clear_pass: vk.RenderPass,
render_pass: vk.RenderPass,

target: vk.Image,
target_view: vk.ImageView,
depth: vk.Image,
depth_view: vk.ImageView,
clear_framebuffer: vk.Framebuffer,
framebuffer: vk.Framebuffer,

camera_state: CameraState,
objects: std.ArrayList(?ObjectState),
meshes: std.ArrayList(?MeshState),
material_state: MaterialState,

sky: Sky,
light: LightState,

staging_buffer: vk.StagingBuffer,

pub fn init(
    allocator: std.mem.Allocator,
    device: vk.Device,
    command_pool: vk.CommandPool,
    target: vk.Image,
) !SceneRenderer {
    const objects = std.ArrayList(?ObjectState).init(allocator);
    const meshes = std.ArrayList(?MeshState).init(allocator);

    var material_state = try MaterialState.init(allocator);
    errdefer material_state.deinit();

    const layouts = try Material.BindGroupLayouts.init(device);
    errdefer layouts.deinit();

    const clear_pass = try createClearPass(device);
    errdefer clear_pass.deinit();

    const render_pass = try createRenderPass(device);
    errdefer render_pass.deinit();

    const target_view = try target.createView(.{
        .aspect = .{ .color = true },
    });
    errdefer target_view.deinit();

    const depth = try createDepthImage(device, target.extent);
    errdefer depth.deinit();

    const depth_view = try depth.createView(.{
        .aspect = .{ .depth = true },
    });
    errdefer depth_view.deinit();

    const clear_framebuffer = try clear_pass.createFramebuffer(.{
        .attachments = &.{
            target_view,
            depth_view,
        },
        .extent = target.extent.as2D(),
    });
    errdefer clear_framebuffer.deinit();

    const framebuffer = try render_pass.createFramebuffer(.{
        .attachments = &.{
            target_view,
            depth_view,
        },
        .extent = target.extent.as2D(),
    });
    errdefer framebuffer.deinit();

    const camera_state = try CameraState.init(device, layouts);
    errdefer camera_state.deinit();

    const light = try LightState.init(device, layouts, target);
    errdefer light.deinit();

    const sky = try Sky.init(device, layouts, target);
    errdefer sky.deinit();

    const staging_buffer = try vk.StagingBuffer.init(device, command_pool);
    errdefer staging_buffer.deinit();

    return .{
        .allocator = allocator,

        .layouts = layouts,
        .clear_pass = clear_pass,
        .render_pass = render_pass,

        .target = target,
        .target_view = target_view,
        .depth = depth,
        .depth_view = depth_view,
        .clear_framebuffer = clear_framebuffer,
        .framebuffer = framebuffer,

        .camera_state = camera_state,
        .objects = objects,
        .meshes = meshes,
        .material_state = material_state,

        .sky = sky,
        .light = light,

        .staging_buffer = staging_buffer,
    };
}

pub fn deinit(self: *SceneRenderer) void {
    self.staging_buffer.deinit();

    self.light.deinit();
    self.sky.deinit();

    self.material_state.deinit();

    for (self.meshes.items) |optional_state| {
        if (optional_state) |state| state.deinit(self.allocator);
    }
    self.meshes.deinit();

    for (self.objects.items) |optional_state| {
        if (optional_state) |state| state.deinit();
    }
    self.objects.deinit();

    self.camera_state.deinit();

    self.framebuffer.deinit();
    self.clear_framebuffer.deinit();
    self.depth_view.deinit();
    self.depth.deinit();
    self.target_view.deinit();

    self.render_pass.deinit();
    self.clear_pass.deinit();
    self.layouts.deinit();
}

pub fn addMaterial(self: *SceneRenderer, comptime T: type, device: vk.Device) !void {
    const cx = .{
        .allocator = &self.allocator,
        .device = &device,
        .staging_buffer = &self.staging_buffer,
    };

    try self.material_state.addMaterial(
        T,
        cx,
        self.layouts,
        self.render_pass,
    );
}

pub fn setTarget(
    self: *SceneRenderer,
    device: vk.Device,
    target: vk.Image,
) !void {
    try self.light.setTarget(device, target);
    try self.sky.setTarget(target);

    self.target = target;

    self.target_view.deinit();
    self.target_view = try target.createView(.{
        .aspect = .{ .color = true },
    });

    self.depth.deinit();
    self.depth = try createDepthImage(device, target.extent);

    self.depth_view.deinit();
    self.depth_view = try self.depth.createView(.{
        .aspect = .{ .depth = true },
    });

    self.clear_framebuffer.deinit();
    self.clear_framebuffer = try self.clear_pass.createFramebuffer(.{
        .attachments = &.{
            self.target_view,
            self.depth_view,
        },
        .extent = target.extent.as2D(),
    });

    self.framebuffer.deinit();
    self.framebuffer = try self.render_pass.createFramebuffer(.{
        .attachments = &.{
            self.target_view,
            self.depth_view,
        },
        .extent = target.extent.as2D(),
    });
}

fn createClearPass(device: vk.Device) !vk.RenderPass {
    return try device.createRenderPass(.{
        .attachments = &.{
            .{
                .format = Renderer.Hdr.COLOR_FORMAT,
                .samples = 1,
                .load_op = .Clear,
                .store_op = .Store,
                .final_layout = .ShaderReadOnlyOptimal,
            },
            .{
                .format = .D32Sfloat,
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
    });
}

fn createRenderPass(device: vk.Device) !vk.RenderPass {
    return try device.createRenderPass(.{
        .attachments = &.{
            .{
                .format = Renderer.Hdr.COLOR_FORMAT,
                .samples = 1,
                .load_op = .Load,
                .store_op = .Store,
                .initial_layout = .ColorAttachmentOptimal,
                .final_layout = .ShaderReadOnlyOptimal,
            },
            .{
                .format = .D32Sfloat,
                .samples = 1,
                .load_op = .Load,
                .store_op = .Store,
                .initial_layout = .DepthStencilAttachmentOptimal,
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
                .dst_stage_mask = .{
                    .color_attachment_output = true,
                    .early_fragment_tests = true,
                },
                .src_stage_mask = .{ .bottom_of_pipe = true },
                .dst_access_mask = .{
                    .color_attachment_write = true,
                    .depth_stencil_attachment_write = true,
                },
            },
        },
    });
}

fn createDepthImage(device: vk.Device, extent: vk.Extent3D) !vk.Image {
    return try device.createImage(.{
        .format = .D32Sfloat,
        .extent = extent,
        .usage = .{
            .depth_stencil_attachment = true,
            .transfer_src = true,
            .sampled = true,
        },
        .memory = .{ .device_local = true },
    });
}

fn resizeArrayList(list: anytype, index: usize) !void {
    if (index >= list.items.len) {
        const new_len = index + 1;
        const old_len = list.items.len;
        try list.resize(new_len);
        @memset(list.items[old_len..new_len], null);
    }
}

fn createObjectState(
    self: *SceneRenderer,
    device: vk.Device,
) !ObjectState {
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

    const bind_group = try bind_group_pool.alloc(self.layouts.model);

    const model_buffer = try device.createBuffer(.{
        .size = @sizeOf(ModelUniforms),
        .usage = .{ .uniform_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer model_buffer.deinit();

    device.updateBindGroups(.{
        .writes = &.{
            .{
                .dst = bind_group,
                .binding = 0,
                .resource = .{
                    .buffer = .{
                        .buffer = model_buffer,
                        .size = @sizeOf(ModelUniforms),
                    },
                },
            },
        },
    });

    return .{
        .bind_group_pool = bind_group_pool,
        .bind_group = bind_group,
        .model_buffer = model_buffer,
    };
}

fn createMeshState(
    self: *SceneRenderer,
    device: vk.Device,
    mesh_entry: *Meshes.Entry,
) !MeshState {
    const vertex_buffers = try self.allocator.alloc(
        VertexBuffer,
        mesh_entry.value.attributes.items.len,
    );
    errdefer self.allocator.free(vertex_buffers);

    for (mesh_entry.value.attributes.items, 0..) |attribute, i| {
        const size = attribute.vertices.data.items.len;
        const buffer = try device.createBuffer(.{
            .size = size,
            .usage = .{ .vertex_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });
        errdefer buffer.deinit();

        try self.staging_buffer.write(attribute.vertices.data.items);
        try self.staging_buffer.copyBuffer(.{
            .dst = buffer,
            .size = size,
        });

        vertex_buffers[i] = .{
            .name = attribute.name,
            .buffer = buffer,
        };
    }

    const index_buffer = try device.createBuffer(.{
        .size = mesh_entry.value.indexBytes().len,
        .usage = .{ .index_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer index_buffer.deinit();

    try self.staging_buffer.write(mesh_entry.value.indexBytes());
    try self.staging_buffer.copyBuffer(.{
        .dst = index_buffer,
        .size = mesh_entry.value.indexBytes().len,
    });

    return .{
        .vertex_buffers = vertex_buffers,
        .index_buffer = index_buffer,
        .index_count = @intCast(mesh_entry.value.indices.items.len),
        .generation = mesh_entry.generation,
        .version = mesh_entry.version,
    };
}

fn materialContext(
    self: *SceneRenderer,
) Material.Context {
    return .{
        .allocator = &self.allocator,
        .device = &self.device,
        .staging_buffer = &self.staging_buffer,
    };
}

fn getObjectState(
    self: *SceneRenderer,
    device: vk.Device,
    index: usize,
) !*ObjectState {
    try resizeArrayList(&self.objects, index);
    if (self.objects.items[index]) |*state| return state;

    self.objects.items[index] = try self.createObjectState(device);
    return &self.objects.items[index].?;
}

fn getMeshState(
    self: *SceneRenderer,
    device: vk.Device,
    mesh_entry: *Meshes.Entry,
    index: usize,
) !*MeshState {
    try resizeArrayList(&self.meshes, index);
    if (self.meshes.items[index]) |*state| return state;

    self.meshes.items[index] = try self.createMeshState(device, mesh_entry);
    return &self.meshes.items[index].?;
}

fn prepareObjectState(
    self: *SceneRenderer,
    object_state: *ObjectState,
    object: Object,
) !void {
    const model_uniforms = ModelUniforms{
        .model = object.transform.computeMatrix(),
    };

    try self.staging_buffer.write(&model_uniforms);
    try self.staging_buffer.copyBuffer(.{
        .dst = object_state.model_buffer,
        .size = @sizeOf(ModelUniforms),
    });
}

fn prepareCameraState(
    self: *SceneRenderer,
    camera: Camera,
) !void {
    const uniforms = camera.uniforms(self.target.extent.aspectRatio());
    try self.camera_state.prepare(&self.staging_buffer, uniforms);
}

fn prepareMeshState(
    self: *SceneRenderer,
    device: vk.Device,
    mesh_state: *MeshState,
    entry: *Meshes.Entry,
) !void {
    if (mesh_state.version != entry.version or
        mesh_state.generation != entry.generation)
    {
        mesh_state.deinit(self.allocator);
        mesh_state.* = try self.createMeshState(device, entry);
    }
}

pub fn prepare(
    self: *SceneRenderer,
    device: vk.Device,
    materials: Materials,
    meshes: Meshes,
    scene: Scene,
) !void {
    try self.prepareCameraState(scene.camera);

    for (scene.objects.items, 0..) |object, i| {
        const object_state = try self.getObjectState(device, i);
        try self.prepareObjectState(object_state, object);
    }

    for (meshes.entries.items, 0..) |*optional_entry, i| {
        if (optional_entry.*) |*entry| {
            const mesh_state = try self.getMeshState(device, entry, i);
            try self.prepareMeshState(device, mesh_state, entry);
        }
    }

    const cx = .{
        .allocator = &self.allocator,
        .device = &device,
        .staging_buffer = &self.staging_buffer,
    };

    try self.material_state.prepare(cx, materials);
}

fn recordDrawObjects(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
    scene: Scene,
    read_transmission: bool,
) void {
    for (scene.objects.items, 0..) |object, i| {
        const object_state = self.objects.items[i] orelse continue;
        const mesh_state = self.meshes.items[object.mesh.index] orelse continue;
        const instance = self.material_state.getInstance(object.material) orelse continue;
        const pipeline = self.material_state.getPipeline(instance.type_id) orelse continue;

        if (instance.reads_transmission != read_transmission) continue;

        command_buffer.bindGraphicsPipeline(pipeline.pipeline);
        command_buffer.bindBindGroup(pipeline.pipeline, 0, instance.bind_group, &.{});
        command_buffer.bindBindGroup(pipeline.pipeline, 1, object_state.bind_group, &.{});
        command_buffer.bindBindGroup(pipeline.pipeline, 2, self.camera_state.bind_group, &.{});
        command_buffer.bindBindGroup(pipeline.pipeline, 3, self.light.bind_group, &.{});

        for (pipeline.material.vertexAttributes(), 0..) |attribute, j| {
            const buffer = mesh_state.getBuffer(attribute.name) orelse continue;
            command_buffer.bindVertexBuffer(@intCast(j), buffer, 0);
        }

        command_buffer.bindIndexBuffer(mesh_state.index_buffer, 0, .u32);

        command_buffer.drawIndexed(.{
            .index_count = mesh_state.index_count,
        });
    }
}

fn copyTransmissionImage(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
) void {
    command_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .ShaderReadOnlyOptimal,
                .new_layout = .TransferSrcOptimal,
                .image = self.target,
                .aspect = .{ .color = true },
            },
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .Undefined,
                .new_layout = .TransferDstOptimal,
                .image = self.light.transmission_image,
                .aspect = .{ .color = true },
                .level_count = self.light.transmission_image.mip_levels,
            },
        },
    });

    command_buffer.copyImageToImage(.{
        .src = self.target,
        .src_layout = .TransferSrcOptimal,
        .dst = self.light.transmission_image,
        .dst_layout = .TransferDstOptimal,
        .region = .{
            .src_aspect = .{ .color = true },
            .dst_aspect = .{ .color = true },
            .extent = self.target.extent,
        },
    });

    command_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .TransferDstOptimal,
                .new_layout = .General,
                .image = self.light.transmission_image,
                .aspect = .{ .color = true },
                .level_count = self.light.transmission_image.mip_levels,
            },
        },
    });
}

fn updateTransmissionImage(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
) void {
    self.copyTransmissionImage(command_buffer);

    self.light.transmission_downsample.dispatch(command_buffer);

    command_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .TransferSrcOptimal,
                .new_layout = .ColorAttachmentOptimal,
                .image = self.target,
                .aspect = .{ .color = true },
            },
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .General,
                .new_layout = .ShaderReadOnlyOptimal,
                .image = self.light.transmission_image,
                .aspect = .{ .color = true },
                .level_count = self.light.transmission_image.mip_levels,
            },
        },
    });
}

fn transferScreenImage(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
) void {
    command_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .Undefined,
                .new_layout = .ShaderReadOnlyOptimal,
                .image = self.light.transmission_image,
                .aspect = .{ .color = true },
                .level_count = self.light.transmission_image.mip_levels,
            },
        },
    });
}

fn recordOpaquePass(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
    scene: Scene,
) void {
    command_buffer.beginRenderPass(.{
        .render_pass = self.render_pass,
        .framebuffer = self.framebuffer,
        .render_area = .{
            .extent = self.target.extent.as2D(),
        },
    });

    self.recordDrawObjects(command_buffer, scene, false);

    command_buffer.endRenderPass();
}

fn recordTransmissivePass(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
    scene: Scene,
) void {
    command_buffer.beginRenderPass(.{
        .render_pass = self.render_pass,
        .framebuffer = self.framebuffer,
        .render_area = .{
            .extent = self.target.extent.as2D(),
        },
    });

    self.recordDrawObjects(command_buffer, scene, true);

    command_buffer.endRenderPass();
}

fn recordClearPass(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
) void {
    command_buffer.beginRenderPass(.{
        .render_pass = self.clear_pass,
        .framebuffer = self.clear_framebuffer,
        .render_area = .{
            .extent = self.target.extent.as2D(),
        },
    });

    command_buffer.endRenderPass();
}

pub fn draw(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
    scene: Scene,
) !void {
    self.recordClearPass(command_buffer);

    self.sky.record(command_buffer, self.camera_state);

    self.transferScreenImage(command_buffer);

    self.recordOpaquePass(command_buffer, scene);

    self.updateTransmissionImage(command_buffer);

    self.recordTransmissivePass(command_buffer, scene);
}
