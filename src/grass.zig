const std = @import("std");
const vk = @import("vulkan");

const engine = @import("engine.zig");

fn random(st: engine.Vec2) f32 {
    return @mod(@sin(st.dot(engine.Vec2.init(12.9898, 78.233))) * 43758.5453123, 1.0);
}

fn generateBlade(
    position: engine.Vec3,
    positions: *engine.Mesh.Vertices([3]f32),
    tex_coords: *engine.Mesh.Vertices([2]f32),
    stiffness: *engine.Mesh.Vertices(f32),
    indices: *std.ArrayList(u32),
) !void {
    const segments = 6;
    const width = 0.08;
    const height = 1.3;

    const angle = random(position.swizzle("xz")) * 3.14159 * 2.0;

    const offset_x = random(position.swizzle("xz").add(132.0)) * 0.1 - 0.05;
    const offset_z = random(position.swizzle("xz").add(567.0)) * 0.1 - 0.05;

    for (0..segments) |i| {
        const v = @as(f32, @floatFromInt(i)) /
            @as(f32, @floatFromInt(segments - 1));

        const width_factor = std.math.pow(f32, 1.0 - v, 0.8);

        const right = engine.Vec3.init(
            width / 2.0 * width_factor * @sin(angle) + offset_x,
            v * height,
            width / 2.0 * width_factor * @cos(angle) + offset_z,
        );
        const left = engine.Vec3.init(
            -width / 2.0 * width_factor * @sin(angle) + offset_x,
            v * height,
            -width / 2.0 * width_factor * @cos(angle) + offset_z,
        );

        try positions.append(position.add(right).f);
        try positions.append(position.add(left).f);

        try tex_coords.append(.{ 0.0, v });
        try tex_coords.append(.{ 1.0, v });

        try stiffness.append(1.0 - v);
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

    for (0..500) |x_i| {
        for (0..500) |z_i| {
            const x = @as(f32, @floatFromInt(x_i)) / 10.0 - 25.0;
            const z = @as(f32, @floatFromInt(z_i)) / 10.0 - 25.0;
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

pub fn system(
    time: *engine.Time,
    materials: *engine.Assets(Material),
) !void {
    var it = materials.iterator();
    while (it.next()) |entry| {
        _ = try materials.getPtr(entry.id);
        entry.asset.item.time = time.since_start;
    }
}

pub const Material = struct {
    time: f32 = 0.0,

    pub fn vertexShader() vk.Spirv {
        return vk.embedSpirv(@embedFile("shaders/grass.vert"));
    }

    pub fn fragmentShader() vk.Spirv {
        return vk.embedSpirv(@embedFile("shaders/grass.frag"));
    }

    pub fn vertexAttributes() []const engine.VertexAttribute {
        return &.{
            .{ .name = engine.Mesh.POSITION, .format = .f32x3 },
            .{ .name = "stiffness", .format = .f32x1 },
        };
    }

    pub fn bindGroupLayoutEntries() []const vk.BindGroupLayout.Entry {
        return &.{
            .{
                .binding = 0,
                .type = .UniformBuffer,
                .stages = .{ .vertex = true, .fragment = true },
            },
        };
    }

    pub fn materialPipeline() engine.MaterialPipeline {
        return .{
            .rasterization = .{
                .cull_mode = .{},
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
            },
        });
    }
};
