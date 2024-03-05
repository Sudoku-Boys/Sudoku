const std = @import("std");
const vk = @import("vk");

const Engine = @import("../Engine.zig");
const Mesh = @import("Mesh.zig");
const World = @import("../World.zig");

const asset = @import("../asset.zig");

pub fn MaterialPlugin(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn buildPlugin(self: MaterialPlugin, engine: *Engine) !void {
            const material_system = try engine.addSystem(MaterialSystem(T));
            _ = material_system;

            _ = self;
        }
    };
}

pub fn MaterialSystem(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn run(self: Self, world: *World) !void {
            const assets = try world.resource(asset.Assets(T));
            _ = assets;

            _ = self;
        }
    };
}

pub const Context = struct {
    allocator: *std.mem.Allocator,
    device: *const vk.Device,
    staging_buffer: *vk.StagingBuffer,
};

pub const VertexAttribute = struct {
    name: []const u8,
    format: vk.VertexFormat,
};

pub const BindGroupLayouts = struct {
    model: vk.BindGroupLayout,
    camera: vk.BindGroupLayout,
    light: vk.BindGroupLayout,

    pub fn init(device: vk.Device) !BindGroupLayouts {
        const model = try createModel(device);
        errdefer model.deinit();

        const camera = try createCamera(device);
        errdefer camera.deinit();

        const light = try createLight(device);
        errdefer light.deinit();

        return .{
            .model = model,
            .camera = camera,
            .light = light,
        };
    }

    pub fn deinit(self: BindGroupLayouts) void {
        self.model.deinit();
        self.camera.deinit();
        self.light.deinit();
    }

    fn createModel(device: vk.Device) !vk.BindGroupLayout {
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

    fn createCamera(device: vk.Device) !vk.BindGroupLayout {
        return try device.createBindGroupLayout(.{
            .entries = &.{
                .{
                    .binding = 0,
                    .type = .UniformBuffer,
                    .stages = .{ .vertex = true, .fragment = true },
                },
            },
        });
    }

    fn createLight(device: vk.Device) !vk.BindGroupLayout {
        return try device.createBindGroupLayout(.{
            .entries = &.{
                .{
                    .binding = 0,
                    .stages = .{ .fragment = true },
                    .type = .CombinedImageSampler,
                },
            },
        });
    }
};

pub const Pipeline = struct {
    input_assembly: vk.GraphicsPipeline.InputAssembly = .{},
    rasterization: vk.GraphicsPipeline.Rasterization = .{},
    depth_stencil: ?vk.GraphicsPipeline.DepthStencil = .{
        .depth_test = true,
        .depth_write = true,
    },
    color_attachment: vk.GraphicsPipeline.ColorBlendAttachment = .{},
};

pub fn Material(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn vertexShader() vk.Spirv {
            if (@hasDecl(T, "vertexShader")) {
                return T.vertexShader();
            } else {
                return vk.embedSpirv(@embedFile("shaders/default.vert"));
            }
        }

        pub fn fragmentShader() vk.Spirv {
            if (@hasDecl(T, "fragmentShader")) {
                return T.fragmentShader();
            } else {
                return vk.embedSpirv(@embedFile("shaders/default.frag"));
            }
        }

        pub fn vertexAttributes() []const VertexAttribute {
            if (@hasDecl(T, "vertexAttributes")) {
                return T.vertexAttributes();
            } else {
                return &.{
                    .{ .name = Mesh.POSITION, .format = .f32x3 },
                    .{ .name = Mesh.NORMAL, .format = .f32x3 },
                    .{ .name = Mesh.TEX_COORD_0, .format = .f32x2 },
                };
            }
        }

        pub fn pipeline() Pipeline {
            if (@hasDecl(T, "pipeline")) {
                return T.pipeline();
            } else {
                return .{};
            }
        }

        pub fn bindGroupLayoutEntries() []const vk.BindGroupLayout.Entry {
            return T.bindGroupLayoutEntries();
        }
    };
}

pub fn MaterialPipeline(comptime T: type) type {
    return struct {
        const Self = @This();

        bind_group_layout: vk.BindGroupLayout,
        pipeline: vk.GraphicsPipeline,

        pub fn init(
            allocator: std.mem.Allocator,
            device: vk.Device,
            layouts: BindGroupLayouts,
            render_pass: vk.RenderPass,
        ) !Self {
            const bind_group_layout_entries = Material(T).bindGroupLayoutEntries();

            const bind_group_layout = try device.createBindGroupLayout(.{
                .entries = bind_group_layout_entries,
            });

            const material_attributes = Material(T).vertexAttributes();

            const vertex_bindings = try allocator.alloc(
                vk.GraphicsPipeline.VertexBinding,
                material_attributes.len,
            );
            defer allocator.free(vertex_bindings);

            const vertex_attributes = try allocator.alloc(
                vk.GraphicsPipeline.VertexAttribute,
                material_attributes.len,
            );
            defer allocator.free(vertex_attributes);

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

            const material_pipeline = Material(T).pipeline();

            const pipeline = try device.createGraphicsPipeline(.{
                .vertex = .{
                    .shader = Material(T).vertexShader(),
                    .entry_point = "main",
                    .bindings = vertex_bindings,
                },
                .fragment = .{
                    .shader = Material(T).fragmentShader(),
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
                .bind_group_layout = bind_group_layout,
                .pipeline = pipeline,
            };
        }

        pub fn deinit(self: Self) void {
            self.bind_group_layout.deinit();
            self.pipeline.deinit();
        }
    };
}
