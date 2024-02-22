const std = @import("std");
const vk = @import("vulkan");

const asset = @import("../asset.zig");
const Material = @import("Material.zig");
const Materials = @import("Materials.zig");

const TypeId = std.builtin.TypeId;

const MaterialState = @This();

pub const Instance = struct {
    type_id: TypeId,
    bind_group_pool: vk.BindGroupPool,
    bind_group: vk.BindGroup,
    opaque_state: *anyopaque,
    reads_screen_image: bool,

    fn init(
        cx: Material.Context,
        pipeline: Pipeline,
        material: *anyopaque,
    ) !Instance {
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

        const bind_group_pool = try cx.device.createBindGroupPool(.{
            .pool_sizes = pool_sizes[0..pool_size_count],
            .max_groups = 1,
        });
        errdefer bind_group_pool.deinit();

        const bind_group = try bind_group_pool.alloc(pipeline.bind_group_layout);

        const opaque_data = try pipeline.material.allocState(cx.allocator);
        errdefer pipeline.material.freeState(cx.allocator, opaque_data);

        try pipeline.material.initState(opaque_data, cx, bind_group);

        var state = .{
            .type_id = pipeline.material.type_id,
            .bind_group_pool = bind_group_pool,
            .bind_group = bind_group,
            .opaque_state = opaque_data,
            .reads_screen_image = false,
        };

        try state.update(pipeline, material);

        return state;
    }

    fn update(
        self: *Instance,
        cx: Material.Context,
        pipeline: Pipeline,
        material: *anyopaque,
    ) !void {
        try pipeline.material.update(material, self.opaque_state, cx);
        self.reads_screen_image = pipeline.material.readsScreenImage(material);
    }

    pub fn deinit(
        self: Instance,
        allocator: std.mem.Allocator,
        material: Material,
    ) void {
        material.deinitState(self.opaque_state);
        material.freeState(allocator, self.opaque_state);

        self.bind_group_pool.deinit();
    }
};

pub const Pipeline = struct {
    bind_group_layout: vk.BindGroupLayout,
    pipeline: vk.GraphicsPipeline,
    material: Material,

    fn init(
        cx: Material.Context,
        material: Material,
        layouts: Material.BindGroupLayouts,
        render_pass: vk.RenderPass,
    ) !Pipeline {
        const bind_group_layout_entries = material.bindGroupLayoutEntries();

        const bind_group_layout = try cx.device.createBindGroupLayout(.{
            .entries = bind_group_layout_entries,
        });

        const material_attributes = material.vertexAttributes();

        const vertex_bindings = try cx.allocator.alloc(
            vk.GraphicsPipeline.VertexBinding,
            material_attributes.len,
        );
        defer cx.allocator.free(vertex_bindings);

        const vertex_attributes = try cx.allocator.alloc(
            vk.GraphicsPipeline.VertexAttribute,
            material_attributes.len,
        );
        defer cx.allocator.free(vertex_attributes);

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

        const pipeline = try cx.device.createGraphicsPipeline(.{
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
                layouts.model,
                layouts.camera,
                layouts.light,
            },
            .render_pass = render_pass,
            .subpass = 0,
        });

        return .{
            .material = material,
            .pipeline = pipeline,
            .bind_group_layout = bind_group_layout,
        };
    }

    pub fn deinit(self: Pipeline) void {
        self.pipeline.deinit();
        self.bind_group_layout.deinit();
    }
};

allocator: std.mem.Allocator,
instances: std.AutoHashMapUnmanaged(asset.DynamicAssetId, Instance),
pipelines: std.AutoHashMapUnmanaged(TypeId, Pipeline),

pub fn init(allocator: std.mem.Allocator) !MaterialState {
    return .{
        .allocator = allocator,
        .instances = .{},
        .pipelines = .{},
    };
}

pub fn deinit(self: *MaterialState) void {
    var instances = self.instances.valueIterator();
    while (instances.next()) |instance| {
        const pipeline = self.pipelines.get(instance.type_id).?;

        instance.deinit(self.allocator, pipeline.material);
    }

    self.instances.deinit(self.allocator);

    var pipelines = self.pipelines.valueIterator();
    while (pipelines.next()) |pipeline| {
        pipeline.deinit();
    }

    self.pipelines.deinit(self.allocator);
}

pub fn addMaterial(
    self: *MaterialState,
    comptime T: type,
    cx: Material.Context,
    layouts: Material.BindGroupLayouts,
    render_pass: vk.RenderPass,
) !void {
    const type_id = std.meta.activeTag(@typeInfo(T));

    if (self.pipelines.contains(type_id)) return;

    const material = Material.init(T);
    const pipeline = try Pipeline.init(cx, material, layouts, render_pass);

    try self.pipelines.put(self.allocator, type_id, pipeline);
}

pub fn getInstance(
    self: MaterialState,
    asset_id: asset.DynamicAssetId,
) ?Instance {
    return self.instances.get(asset_id);
}

pub fn getPipeline(
    self: MaterialState,
    type_id: TypeId,
) ?Pipeline {
    return self.pipelines.get(type_id);
}

fn prepareMaterialState(
    self: *MaterialState,
    instance: *Instance,
    pipeline: Pipeline,
    entry: *Materials.Entry,
) !void {
    if (instance.generation != entry.generation) {
        instance.deinit(self.allocator, pipeline.material);
        instance.* = try self.createMaterialState(pipeline, entry);
    }

    if (instance.version != entry.version) {
        try self.updateMaterialState(
            pipeline,
            instance,
            entry.value,
        );

        instance.version = entry.version;
    }
}

pub fn prepare(
    self: *MaterialState,
    cx: Material.Context,
    materials: Materials,
) !void {
    _ = materials;
    _ = cx;
    _ = self;
}
