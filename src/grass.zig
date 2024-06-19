const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");

fn generateBlade(
    position: engine.Vec3,
    positions: *engine.Mesh.Vertices([3]f32),
    tex_coords: *engine.Mesh.Vertices([2]f32),
    stiffness: *engine.Mesh.Vertices(f32),
    indices: *std.ArrayList(u32),
) !void {
    const segments = 8;
    const width = 0.1;
    const height = 1.0;

    for (0..segments) |i| {
        const v = @as(f32, @floatFromInt(i)) /
            @as(f32, @floatFromInt(segments - 1));

        const right = engine.Vec3.init(width / 2.0, v * height, 0.0);
        const left = engine.Vec3.init(-width / 2.0, v * height, 0.0);

        try positions.append(position.add(right).f);
        try positions.append(position.add(left).f);

        try tex_coords.append(.{ 0.0, v });
        try tex_coords.append(.{ 1.0, v });

        try stiffness.append(1.0 - v);

        if (i > 0) {
            const a = @as(u32, @intCast(positions.len())) - 4;
            const b = @as(u32, @intCast(positions.len())) - 3;
            const c = @as(u32, @intCast(positions.len())) - 2;
            const d = @as(u32, @intCast(positions.len())) - 1;

            try indices.append(a);
            try indices.append(b);
            try indices.append(c);

            try indices.append(b);
            try indices.append(d);
            try indices.append(c);
        }
    }
}

pub fn generateMesh(allocator: std.mem.Allocator) !engine.Mesh {
    var mesh = engine.Mesh.init(allocator);

    _ = try mesh.addAttribute([3]f32, engine.Mesh.POSITION);
    _ = try mesh.addAttribute([2]f32, engine.Mesh.TEX_COORD_0);
    _ = try mesh.addAttribute(f32, "stiffness");

    const positions = mesh.getAttributePtr([3]f32, engine.Mesh.POSITION).?;
    const tex_coords = mesh.getAttributePtr([2]f32, engine.Mesh.TEX_COORD_0).?;
    const stiffness = mesh.getAttributePtr(f32, "stiffness").?;

    for (0..100) |x_i| {
        for (0..100) |z_i| {
            const x = @as(f32, @floatFromInt(x_i)) / 100.0;
            const z = @as(f32, @floatFromInt(z_i)) / 100.0;
            const position = engine.Vec3.init(x, 0.0, z);

            try generateBlade(
                position,
                positions,
                tex_coords,
                stiffness,
                &mesh.indices,
            );
        }
    }

    return mesh;
}

pub const Material = struct {
    time: f32 = 0.0,
    texture: ?engine.AssetId(engine.Image) = null,

    pub fn vertexShader() vk.Spirv {
        return vk.embedSpirv(@embedFile("shaders/grass.vert"));
    }

    pub fn fragmentShader() vk.Spirv {
        return vk.embedSpirv(@embedFile("shaders/grass.frag"));
    }

    pub fn vertexAttributes() []const engine.VertexAttribute {
        return &.{
            .{ .name = engine.Mesh.POSITION, .format = .f32x3 },
            .{ .name = engine.Mesh.NORMAL, .format = .f32x3 },
            .{ .name = engine.Mesh.TANGENT, .format = .f32x4 },
            .{ .name = engine.Mesh.TEX_COORD_0, .format = .f32x2 },
            .{ .name = "stiffness", .format = .f32x1 },
        };
    }

    pub fn bindGroupLayoutEntries() []const vk.BindGroupLayout.Entry {
        return &.{
            .{
                .binding = 0,
                .type = .UniformBuffer,
                .stages = .{ .fragment = true },
            },
            .{
                .binding = 1,
                .type = .CombinedImageSampler,
                .stages = .{ .fragment = true },
            },
        };
    }

    pub const Uniforms = extern struct {
        time: f32,
    };

    pub const State = struct {
        uniform_buffer: vk.Buffer,
    };

    pub fn initState(
        device: vk.Device,
        bind_group: vk.BindGroup,
    ) !State {
        _ = bind_group;

        const uniform_buffer = try device.createBuffer(.{
            .size = @sizeOf(Uniforms),
            .usage = .{ .uniform_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });

        return .{
            .uniform_buffer = uniform_buffer,
        };
    }

    pub fn deinitState(state: *State) void {
        state.uniform_buffer.deinit();
    }

    pub fn update(
        self: Material,
        state: *State,
        bind_group: vk.BindGroup,
        cx: engine.MaterialContext,
    ) !void {
        const uniforms = Uniforms{
            .time = self.time,
        };

        try cx.staging_buffer.write(&uniforms);
        try cx.staging_buffer.copyBuffer(.{
            .dst = state.uniform_buffer,
            .size = @sizeOf(Uniforms),
        });

        const texture = cx.get_image(self.texture);

        cx.device.updateBindGroups(.{
            .writes = &.{
                .{
                    .dst = bind_group,
                    .binding = 0,
                    .resource = .{ .buffer = .{
                        .buffer = state.uniform_buffer,
                        .size = @sizeOf(Uniforms),
                    } },
                },
                .{
                    .dst = bind_group,
                    .binding = 1,
                    .resource = .{ .combined_image = .{
                        .sampler = texture.sampler,
                        .view = texture.view,
                        .layout = .ShaderReadOnlyOptimal,
                    } },
                },
            },
        });
    }
};
