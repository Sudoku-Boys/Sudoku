const std = @import("std");
const vk = @import("vulkan");

const Camera = @import("Camera.zig");
const Downsample = @import("Downsample.zig");
const Material = @import("Material.zig");
const Materials = @import("Materials.zig").Materials;
const Mesh = @import("Mesh.zig");
const Meshes = @import("Meshes.zig").Meshes;
const Object = @import("Object.zig");
const OpaqueMaterial = @import("OpagueWrapper.zig");
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

const MaterialState = struct {
    type_id: TypeId,
    bind_group_pool: vk.BindGroupPool,
    bind_group: vk.BindGroup,
    opaque_state: *anyopaque,
    reads_transmission: bool,
    generation: u64,
    version: u64,

    pub fn deinit(
        self: MaterialState,
        allocator: std.mem.Allocator,
        material: Material,
    ) void {
        material.deinitState(self.opaque_state);
        material.freeState(allocator, self.opaque_state);

        self.bind_group_pool.deinit();
    }
};

const MaterialPipeline = struct {
    bind_group_layout: vk.BindGroupLayout,
    pipeline: vk.GraphicsPipeline,
    material: Material,

    pub fn deinit(self: MaterialPipeline) void {
        self.pipeline.deinit();
        self.bind_group_layout.deinit();
    }
};

const LightState = struct {
    bind_group_layout: vk.BindGroupLayout,
    bind_group_pool: vk.BindGroupPool,
    bind_group: vk.BindGroup,

    transmission_downsample: Downsample,
    transmission_image: vk.Image,
    transmission_image_view: vk.ImageView,
    transmission_sampler: vk.Sampler,

    fn init(device: vk.Device, extent: vk.Extent3D) !LightState {
        const bind_group_layout = try device.createBindGroupLayout(.{
            .entries = &.{
                .{
                    .binding = 0,
                    .stages = .{ .fragment = true },
                    .type = .CombinedImageSampler,
                },
            },
        });
        errdefer bind_group_layout.deinit();

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

        const bind_group = try bind_group_pool.alloc(bind_group_layout);

        const transmission_image = try createTransmissionImage(device, extent);
        errdefer transmission_image.deinit();

        const transmission_image_view = try transmission_image.createView(.{
            .format = Renderer.Hdr.COLOR_FORMAT,
            .aspect = .{ .color = true },
            .mip_levels = transmission_image.mip_levels,
        });
        errdefer transmission_image_view.deinit();

        const transmission_sampler = try device.createSampler(.{
            .min_filter = .Linear,
            .mag_filter = .Linear,
            .address_mode_u = .ClampToEdge,
            .address_mode_v = .ClampToEdge,
            .address_mode_w = .ClampToEdge,
            .mipmap_mode = .Linear,
            .min_lod = 0.0,
            .max_lod = 100.0,
        });
        errdefer transmission_sampler.deinit();

        device.updateBindGroups(.{
            .writes = &.{
                .{
                    .dst = bind_group,
                    .binding = 0,
                    .resource = .{
                        .combined_image = .{
                            .layout = .ShaderReadOnlyOptimal,
                            .view = transmission_image_view,
                            .sampler = transmission_sampler,
                        },
                    },
                },
            },
        });

        const transmission_downsample = try Downsample.init(device);

        return .{
            .bind_group_layout = bind_group_layout,
            .bind_group_pool = bind_group_pool,
            .bind_group = bind_group,

            .transmission_downsample = transmission_downsample,
            .transmission_image = transmission_image,
            .transmission_image_view = transmission_image_view,
            .transmission_sampler = transmission_sampler,
        };
    }

    pub fn deinit(self: LightState) void {
        self.transmission_downsample.deinit();
        self.transmission_image_view.deinit();
        self.transmission_image.deinit();
        self.transmission_sampler.deinit();

        self.bind_group_pool.deinit();
        self.bind_group_layout.deinit();
    }

    fn createTransmissionImage(device: vk.Device, extent: vk.Extent3D) !vk.Image {
        const min_extent = @min(extent.width, extent.height);
        const mip_level = std.math.log2(min_extent) + 1;

        return try device.createImage(.{
            .format = Renderer.Hdr.COLOR_FORMAT,
            .extent = extent,
            .mip_levels = mip_level,
            .usage = .{
                .transfer_dst = true,
                .sampled = true,
                .storage = true,
            },
            .memory = .{ .device_local = true },
        });
    }

    fn resize(self: *LightState, device: vk.Device, extent: vk.Extent3D) !void {
        self.transmission_image.deinit();
        self.transmission_image = try createTransmissionImage(device, extent);

        self.transmission_image_view.deinit();
        self.transmission_image_view = try self.transmission_image.createView(.{
            .format = Renderer.Hdr.COLOR_FORMAT,
            .aspect = .{ .color = true },
            .mip_levels = self.transmission_image.mip_levels,
        });

        device.updateBindGroups(.{
            .writes = &.{
                .{
                    .dst = self.bind_group,
                    .binding = 0,
                    .resource = .{
                        .combined_image = .{
                            .layout = .ShaderReadOnlyOptimal,
                            .view = self.transmission_image_view,
                            .sampler = self.transmission_sampler,
                        },
                    },
                },
            },
        });
    }
};

allocator: std.mem.Allocator,
device: vk.Device,

hdr_render_pass: vk.RenderPass,
hdr_subpass: u32,

extent: vk.Extent3D,

object_bind_group_layout: vk.BindGroupLayout,

objects: std.ArrayList(?ObjectState),
meshes: std.ArrayList(?MeshState),
materials: std.ArrayList(?MaterialState),
pipelines: std.AutoHashMap(TypeId, MaterialPipeline),

sky: Sky,

staging_buffer: vk.StagingBuffer,

light: LightState,
camera: Camera.RenderState,

pub fn init(
    allocator: std.mem.Allocator,
    device: vk.Device,
    command_pool: vk.CommandPool,
    hdr_render_pass: vk.RenderPass,
    hdr_subpass: u32,
    extent: vk.Extent3D,
) !SceneRenderer {
    const object_bind_group_layout = try createObjectBindGroupLayout(device);
    errdefer object_bind_group_layout.deinit();

    const objects = std.ArrayList(?ObjectState).init(allocator);
    const meshes = std.ArrayList(?MeshState).init(allocator);
    const materials = std.ArrayList(?MaterialState).init(allocator);
    const pipelines = std.AutoHashMap(TypeId, MaterialPipeline).init(allocator);

    const light = try LightState.init(device, extent);
    errdefer light.deinit();
    const camera = try Camera.RenderState.init(device);
    errdefer camera.deinit();

    const sky = try Sky.init(
        device,
        camera.bind_group_layout,
        hdr_render_pass,
        hdr_subpass,
    );
    errdefer sky.deinit();

    const staging_buffer = try vk.StagingBuffer.init(device, command_pool);
    errdefer staging_buffer.deinit();

    return .{
        .allocator = allocator,
        .device = device,

        .hdr_render_pass = hdr_render_pass,
        .hdr_subpass = hdr_subpass,

        .extent = extent,

        .object_bind_group_layout = object_bind_group_layout,

        .objects = objects,
        .meshes = meshes,
        .materials = materials,
        .pipelines = pipelines,

        .sky = sky,

        .staging_buffer = staging_buffer,

        .light = light,
        .camera = camera,
    };
}

pub fn deinit(self: *SceneRenderer) void {
    self.staging_buffer.deinit();

    self.sky.deinit();

    for (self.materials.items) |optional_state| {
        if (optional_state) |state| {
            const pipeline = self.pipelines.get(state.type_id) orelse {
                std.log.warn("Pipeline not found", .{});
                continue;
            };

            state.deinit(self.allocator, pipeline.material);
        }
    }
    self.materials.deinit();

    for (self.meshes.items) |optional_state| {
        if (optional_state) |state| state.deinit(self.allocator);
    }
    self.meshes.deinit();

    for (self.objects.items) |optional_state| {
        if (optional_state) |state| state.deinit();
    }
    self.objects.deinit();

    var it = self.pipelines.valueIterator();
    while (it.next()) |pipeline| {
        pipeline.deinit();
    }
    self.pipelines.deinit();

    self.object_bind_group_layout.deinit();

    self.camera.deinit();
    self.light.deinit();
}

pub fn addMaterial(self: *SceneRenderer, comptime T: type) !void {
    const type_id = std.meta.activeTag(@typeInfo(T));
    if (self.pipelines.contains(type_id)) return;

    const material = Material.init(T);
    const pipeline = try self.createMaterialPipeline(material);

    try self.pipelines.put(type_id, pipeline);
}

pub fn resize(self: *SceneRenderer, extent: vk.Extent3D) !void {
    self.extent = extent;
    try self.light.resize(self.device, extent);
}

fn createObjectBindGroupLayout(device: vk.Device) !vk.BindGroupLayout {
    return try device.createBindGroupLayout(.{
        .entries = &.{
            .{
                .binding = 0,
                .stages = .{ .vertex = true },
                .type = .UniformBuffer,
            },
        },
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

fn createMaterialPipeline(
    self: *SceneRenderer,
    material: Material,
) !MaterialPipeline {
    const bind_group_layout_entries = material.bindGroupLayoutEntries();

    const bind_group_layout = try self.device.createBindGroupLayout(.{
        .entries = bind_group_layout_entries,
    });

    const material_attributes = material.vertexAttributes();

    const vertex_bindings = try self.allocator.alloc(
        vk.GraphicsPipeline.VertexBinding,
        material_attributes.len,
    );
    defer self.allocator.free(vertex_bindings);

    const vertex_attributes = try self.allocator.alloc(
        vk.GraphicsPipeline.VertexAttribute,
        material_attributes.len,
    );
    defer self.allocator.free(vertex_attributes);

    for (material_attributes, 0..) |attribute, i| {
        vertex_attributes[i] = .{
            .location = @intCast(i),
            .format = attribute.format,
            .offset = 0,
        };

        vertex_bindings[i] = .{
            .binding = @intCast(i),
            .stride = attribute.format.size(),
            .input_rate = .Vertex,
            .attributes = vertex_attributes[i .. i + 1],
        };
    }

    const material_pipeline = material.pipeline();

    const pipeline = try self.device.createGraphicsPipeline(.{
        .vertex = .{
            .shader = material.vertexShader(),
            .entry_point = "main",
            .bindings = vertex_bindings,
        },
        .fragment = .{
            .shader = material.fragmentShader(),
            .entry_point = "main",
        },
        .input_assembly = material_pipeline.input_assembly,
        .rasterization = material_pipeline.rasterization,
        .depth_stencil = material_pipeline.depth_stencil,
        .color_blend = .{
            .attachments = &.{
                material_pipeline.color_attachment,
            },
        },
        .layouts = &.{
            bind_group_layout,
            self.object_bind_group_layout,
            self.camera.bind_group_layout,
            self.light.bind_group_layout,
        },
        .render_pass = self.hdr_render_pass,
        .subpass = self.hdr_subpass,
    });

    return .{
        .material = material,
        .pipeline = pipeline,
        .bind_group_layout = bind_group_layout,
    };
}

fn createObjectState(
    self: *SceneRenderer,
) !ObjectState {
    const bind_group_pool = try self.device.createBindGroupPool(.{
        .pool_sizes = &.{
            .{
                .type = .UniformBuffer,
                .count = 1,
            },
        },
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const bind_group = try bind_group_pool.alloc(self.object_bind_group_layout);

    const model_buffer = try self.device.createBuffer(.{
        .size = @sizeOf(ModelUniforms),
        .usage = .{ .uniform_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });
    errdefer model_buffer.deinit();

    self.device.updateBindGroups(.{
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
    mesh_entry: *Meshes.Entry,
) !MeshState {
    const vertex_buffers = try self.allocator.alloc(
        VertexBuffer,
        mesh_entry.value.attributes.items.len,
    );
    errdefer self.allocator.free(vertex_buffers);

    for (mesh_entry.value.attributes.items, 0..) |attribute, i| {
        const size = attribute.vertices.data.items.len;
        const buffer = try self.device.createBuffer(.{
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

    const index_buffer = try self.device.createBuffer(.{
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

fn createMaterialState(
    self: *SceneRenderer,
    pipeline: MaterialPipeline,
    material_entry: *Materials.Entry,
) !MaterialState {
    var pool_sizes: [vk.BindGroupPool.Descriptor.MAX_POOL_SIZES]vk.BindGroupPool.PoolSize = undefined;
    var pool_size_count: usize = 0;

    const bind_group_layout_entries = pipeline.material.bindGroupLayoutEntries();

    entries: for (bind_group_layout_entries) |entry| {
        for (pool_sizes[0..pool_size_count]) |pool_size| {
            if (pool_size.type == entry.type) {
                pool_size_count += 1;
                continue :entries;
            }
        }

        pool_sizes[pool_size_count] = .{
            .type = entry.type,
            .count = 1,
        };

        pool_size_count += 1;
    }

    const bind_group_pool = try self.device.createBindGroupPool(.{
        .pool_sizes = pool_sizes[0..pool_size_count],
        .max_groups = 1,
    });
    errdefer bind_group_pool.deinit();

    const bind_group = try bind_group_pool.alloc(pipeline.bind_group_layout);

    const opaque_data = try pipeline.material.allocState(self.allocator);
    errdefer pipeline.material.freeState(self.allocator, opaque_data);

    try pipeline.material.initState(
        opaque_data,
        self.materialContext(),
        bind_group,
    );

    var state = .{
        .type_id = pipeline.material.type_id,
        .bind_group_pool = bind_group_pool,
        .bind_group = bind_group,
        .opaque_state = opaque_data,
        .reads_transmission = false,
        .generation = material_entry.generation,
        .version = material_entry.version,
    };

    try self.updateMaterialState(
        pipeline,
        &state,
        material_entry.value,
    );

    return state;
}

fn getObjectState(
    self: *SceneRenderer,
    index: usize,
) !*ObjectState {
    try resizeArrayList(&self.objects, index);
    if (self.objects.items[index]) |*state| return state;

    self.objects.items[index] = try self.createObjectState();
    return &self.objects.items[index].?;
}

fn getMeshState(
    self: *SceneRenderer,
    mesh_entry: *Meshes.Entry,
    index: usize,
) !*MeshState {
    try resizeArrayList(&self.meshes, index);
    if (self.meshes.items[index]) |*state| return state;

    self.meshes.items[index] = try self.createMeshState(mesh_entry);
    return &self.meshes.items[index].?;
}

fn getMaterialState(
    self: *SceneRenderer,
    pipeline: MaterialPipeline,
    material_entry: *Materials.Entry,
    index: usize,
) !*MaterialState {
    try resizeArrayList(&self.materials, index);
    if (self.materials.items[index]) |*state| return state;

    self.materials.items[index] = try self.createMaterialState(pipeline, material_entry);

    return &self.materials.items[index].?;
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
    const camera_uniforms = camera.uniforms(self.extent.aspectRatio());
    try self.staging_buffer.write(&camera_uniforms);
    try self.staging_buffer.copyBuffer(.{
        .dst = self.camera.buffer,
        .size = @sizeOf(Camera.Uniforms),
    });
}

fn updateMaterialState(
    self: *SceneRenderer,
    pipeline: MaterialPipeline,
    material_state: *MaterialState,
    opaque_material: OpaqueMaterial,
) !void {
    try pipeline.material.update(
        opaque_material.data.ptr,
        material_state.opaque_state,
        self.materialContext(),
        material_state.bind_group,
    );

    material_state.reads_transmission = pipeline.material.readsTransmissionImage(
        opaque_material.data.ptr,
    );
}

fn prepareMeshState(
    self: *SceneRenderer,
    mesh_state: *MeshState,
    entry: *Meshes.Entry,
) !void {
    if (mesh_state.version != entry.version or
        mesh_state.generation != entry.generation)
    {
        mesh_state.deinit(self.allocator);
        mesh_state.* = try self.createMeshState(entry);
    }
}

fn prepareMaterialState(
    self: *SceneRenderer,
    material_state: *MaterialState,
    pipeline: MaterialPipeline,
    entry: *Materials.Entry,
) !void {
    if (material_state.generation != entry.generation) {
        material_state.deinit(self.allocator, pipeline.material);
        material_state.* = try self.createMaterialState(pipeline, entry);
    }

    if (material_state.version != entry.version) {
        try self.updateMaterialState(
            pipeline,
            material_state,
            entry.value,
        );

        material_state.version = entry.version;
    }
}

pub fn prepare(
    self: *SceneRenderer,
    materials: Materials,
    meshes: Meshes,
    scene: Scene,
) !void {
    try self.prepareCameraState(scene.camera);

    for (scene.objects.items, 0..) |object, i| {
        const object_state = try self.getObjectState(i);
        try self.prepareObjectState(object_state, object);
    }

    for (meshes.map.entries.items, 0..) |*optional_entry, i| {
        if (optional_entry.*) |*entry| {
            const mesh_state = try self.getMeshState(entry, i);
            try self.prepareMeshState(mesh_state, entry);
        }
    }

    for (materials.map.entries.items, 0..) |*optional_entry, i| {
        if (optional_entry.*) |*entry| {
            const pipeline = self.pipelines.get(entry.value.type_id) orelse continue;
            const material_state = try self.getMaterialState(pipeline, entry, i);
            try self.prepareMaterialState(material_state, pipeline, entry);
        }
    }
}

fn recordObjects(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
    framebuffer: vk.Framebuffer,
    scene: Scene,
    read_transmission: bool,
) void {
    _ = framebuffer;

    for (scene.objects.items, 0..) |object, i| {
        const object_state = self.objects.items[i] orelse continue;
        const mesh_state = self.meshes.items[object.mesh.index] orelse continue;
        const material_state = self.materials.items[object.material.index] orelse continue;
        const pipeline = self.pipelines.get(material_state.type_id) orelse continue;

        if (material_state.reads_transmission != read_transmission) continue;

        command_buffer.bindGraphicsPipeline(pipeline.pipeline);
        command_buffer.bindBindGroup(pipeline.pipeline, 0, material_state.bind_group, &.{});
        command_buffer.bindBindGroup(pipeline.pipeline, 1, object_state.bind_group, &.{});
        command_buffer.bindBindGroup(pipeline.pipeline, 2, self.camera.bind_group, &.{});
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

pub fn draw(
    self: *SceneRenderer,
    command_buffer: vk.CommandBuffer,
    framebuffer: vk.Framebuffer,
    hdr_image: vk.Image,
    scene: Scene,
) !void {
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

    command_buffer.beginRenderPass(.{
        .render_pass = self.hdr_render_pass,
        .framebuffer = framebuffer,
        .render_area = .{
            .extent = self.extent.as2D(),
        },
    });

    try self.sky.record(command_buffer, self.camera);

    self.recordObjects(command_buffer, framebuffer, scene, false);

    command_buffer.endRenderPass();

    command_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .ShaderReadOnlyOptimal,
                .new_layout = .TransferSrcOptimal,
                .image = hdr_image,
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
        .src = hdr_image,
        .src_layout = .TransferSrcOptimal,
        .dst = self.light.transmission_image,
        .dst_layout = .TransferDstOptimal,
        .region = .{
            .src_aspect = .{ .color = true },
            .dst_aspect = .{ .color = true },
            .extent = self.extent,
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

    try self.light.transmission_downsample.setImage(
        self.device,
        self.light.transmission_image,
    );

    self.light.transmission_downsample.dispatch(
        command_buffer,
        self.light.transmission_image,
    );

    command_buffer.pipelineBarrier(.{
        .src_stage = .{ .bottom_of_pipe = true },
        .dst_stage = .{ .top_of_pipe = true },
        .image_barriers = &.{
            .{
                .src_access = .{},
                .dst_access = .{},
                .old_layout = .TransferSrcOptimal,
                .new_layout = .ColorAttachmentOptimal,
                .image = hdr_image,
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

    command_buffer.beginRenderPass(.{
        .render_pass = self.hdr_render_pass,
        .framebuffer = framebuffer,
        .render_area = .{
            .extent = self.extent.as2D(),
        },
    });

    self.recordObjects(command_buffer, framebuffer, scene, true);

    command_buffer.endRenderPass();
}
