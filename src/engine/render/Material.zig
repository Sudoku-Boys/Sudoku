const std = @import("std");
const vk = @import("vulkan");

const Mesh = @import("Mesh.zig");

const Material = @This();

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

pub const VTable = struct {
    vertex_shader: *const fn () vk.Spirv,
    fragment_shader: *const fn () vk.Spirv,
    vertex_attributes: *const fn () []const VertexAttribute,
    pipeline: *const fn () Pipeline,
    bind_group_layout_entries: *const fn () []const vk.BindGroupLayout.Entry,

    reads_screen_image: *const fn (*anyopaque) bool,

    alloc_state: *const fn (std.mem.Allocator) anyerror!*anyopaque,
    free_state: *const fn (std.mem.Allocator, *anyopaque) void,

    init_state: *const fn (*anyopaque, Context, vk.BindGroup) anyerror!void,
    deinit_state: *const fn (*anyopaque) void,
    update: *const fn (*anyopaque, *anyopaque, Context) anyerror!void,
};

vtable: *const VTable,
type_id: std.builtin.TypeId,

pub fn init(comptime T: type) Material {
    return .{
        .vtable = &VTable{
            .vertex_shader = Opaque(T).vertexShader,
            .fragment_shader = Opaque(T).fragmentShader,
            .vertex_attributes = Opaque(T).vertexAttributes,
            .pipeline = Opaque(T).pipeline,
            .bind_group_layout_entries = Opaque(T).bindGroupLayoutEntries,

            .reads_screen_image = Opaque(T).readsScreenImage,

            .alloc_state = Opaque(T).allocState,
            .free_state = Opaque(T).freeState,

            .init_state = Opaque(T).initState,
            .deinit_state = Opaque(T).deinitState,
            .update = Opaque(T).update,
        },
        .type_id = std.meta.activeTag(@typeInfo(T)),
    };
}

fn getState(comptime T: type) ?type {
    if (@hasDecl(T, "State")) {
        return T.State;
    } else {
        return null;
    }
}

fn Opaque(comptime T: type) type {
    return struct {
        fn vertexShader() vk.Spirv {
            if (@hasDecl(T, "vertexShader")) {
                return T.vertexShader();
            } else {
                return vk.embedSpirv(@embedFile("shaders/default.vert"));
            }
        }

        fn fragmentShader() vk.Spirv {
            if (@hasDecl(T, "fragmentShader")) {
                return T.fragmentShader();
            } else {
                return vk.embedSpirv(@embedFile("shaders/default.frag"));
            }
        }

        fn vertexAttributes() []const VertexAttribute {
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

        fn pipeline() Pipeline {
            if (@hasDecl(T, "pipeline")) {
                return T.pipeline();
            } else {
                return .{};
            }
        }

        fn bindGroupLayoutEntries() []const vk.BindGroupLayout.Entry {
            return T.bindGroupLayoutEntries();
        }

        fn readsScreenImage(material: *anyopaque) bool {
            if (@hasDecl(T, "readsScreenImage")) {
                const material_ptr: *T = @ptrCast(@alignCast(material));
                return material_ptr.readsScreenImage();
            } else {
                return false;
            }
        }

        fn allocState(allocator: std.mem.Allocator) !*anyopaque {
            if (getState(T)) |State| {
                if (@sizeOf(State) == 0) return undefined;

                return try allocator.create(State);
            }
        }

        fn freeState(allocator: std.mem.Allocator, state: *anyopaque) void {
            if (getState(T)) |State| {
                if (@sizeOf(State) > 0) {
                    const state_ptr: *State = @ptrCast(@alignCast(state));
                    allocator.destroy(state_ptr);
                }
            }
        }

        fn initState(
            state: *anyopaque,
            cx: Context,
            bind_group: vk.BindGroup,
        ) anyerror!void {
            if (getState(T)) |State| {
                const state_ptr: *State = @ptrCast(@alignCast(state));
                state_ptr.* = try T.initState(cx, bind_group);
            }
        }

        fn deinitState(state: *anyopaque) void {
            if (getState(T)) |State| {
                const state_ptr: *State = @ptrCast(@alignCast(state));
                T.deinitState(state_ptr);
            }
        }

        fn update(material: *anyopaque, state: *anyopaque, cx: Context) anyerror!void {
            const material_ptr: *T = @ptrCast(@alignCast(material));

            if (getState(T)) |State| {
                const state_ptr: *State = @ptrCast(@alignCast(state));
                try T.update(material_ptr, state_ptr, cx);
            } else {
                try material_ptr.update(cx);
            }
        }
    };
}

pub fn vertexShader(self: Material) vk.Spirv {
    return self.vtable.vertex_shader();
}

pub fn fragmentShader(self: Material) vk.Spirv {
    return self.vtable.fragment_shader();
}

pub fn vertexAttributes(self: Material) []const VertexAttribute {
    return self.vtable.vertex_attributes();
}

pub fn pipeline(self: Material) Pipeline {
    return self.vtable.pipeline();
}

pub fn bindGroupLayoutEntries(self: Material) []const vk.BindGroupLayout.Entry {
    return self.vtable.bind_group_layout_entries();
}

pub fn readsScreenImage(
    self: Material,
    material: *anyopaque,
) bool {
    return self.vtable.reads_screen_image(material.data.ptr);
}

pub fn allocState(
    self: Material,
    allocator: std.mem.Allocator,
) !*anyopaque {
    return self.vtable.alloc_state(allocator);
}

pub fn freeState(
    self: Material,
    allocator: std.mem.Allocator,
    state: *anyopaque,
) void {
    self.vtable.free_state(allocator, state);
}

pub fn initState(
    self: Material,
    state: *anyopaque,
    cx: Context,
    bind_group: vk.BindGroup,
) anyerror!void {
    try self.vtable.init_state(state, cx, bind_group);
}

pub fn deinitState(
    self: Material,
    state: *anyopaque,
) void {
    self.vtable.deinit_state(state);
}

pub fn update(
    self: Material,
    material: *anyopaque,
    state: *anyopaque,
    cx: Context,
) anyerror!void {
    try self.vtable.update(material.data.ptr, state, cx);
}
