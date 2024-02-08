const std = @import("std");
const vk = @import("vulkan");
const Color = @import("../Color.zig");
const Material = @import("Material.zig");
const Mesh = @import("Mesh.zig");

const StandardMaterial = @This();

color: Color = Color.WHITE,

pub fn vertexShader() vk.Spirv {
    return vk.embedSpirv(@embedFile("shader/standard_material.vert"));
}

pub fn fragmentShader() vk.Spirv {
    return vk.embedSpirv(@embedFile("shader/standard_material.frag"));
}

pub fn bindGroupLayoutEntries() []const vk.BindGroupLayout.Entry {
    return &.{
        .{
            .binding = 0,
            .type = .UniformBuffer,
            .stages = .{ .fragment = true },
        },
    };
}

pub const Uniforms = extern struct {
    color: [4]f32,
};

pub const State = struct {
    uniform_buffer: vk.Buffer,
};

pub fn initState(
    cx: Material.Context,
    bind_group: vk.BindGroup,
) !State {
    const uniform_buffer = try cx.device.createBuffer(.{
        .size = @sizeOf(Uniforms),
        .usage = .{ .uniform_buffer = true, .transfer_dst = true },
        .memory = .{ .device_local = true },
    });

    cx.device.updateBindGroups(.{
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

    return State{
        .uniform_buffer = uniform_buffer,
    };
}

pub fn deinitState(state: *State) void {
    state.uniform_buffer.deinit();
}

pub fn update(
    self: *StandardMaterial,
    state: *State,
    cx: Material.Context,
) !void {
    const uniforms = Uniforms{
        .color = self.color.asArray(),
    };

    try cx.staging_buffer.write(&uniforms);
    try cx.staging_buffer.copyBuffer(.{
        .dst = state.uniform_buffer,
        .size = @sizeOf(Uniforms),
    });
}
