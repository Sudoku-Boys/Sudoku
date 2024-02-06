const std = @import("std");
const vk = @import("vulkan");
const math = @import("../../math.zig");

const Camera = @This();

pub const Uniforms = extern struct {
    view: [16]f32,
    proj: [16]f32,
    eye: [3]f32,
    _padding0: [4]u8 = undefined,
};

pub const RenderState = struct {
    buffer: vk.Buffer,
    bind_group_pool: vk.BindGroupPool,
    bind_group_layout: vk.BindGroupLayout,
    bind_group: vk.BindGroup,

    pub fn init(device: vk.Device) !RenderState {
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

        const bind_group_layout = try device.createBindGroupLayout(.{
            .bindings = &.{
                .{
                    .binding = 0xffab,
                    .type = .UniformBuffer,
                    .stages = .{ .vertex = true },
                },
            },
        });
        errdefer bind_group_layout.deinit();

        const buffer = try device.createBuffer(.{
            .size = @sizeOf(Camera.Uniforms),
            .usage = .{ .uniform_buffer = true, .transfer_dst = true },
            .memory = .{ .device_local = true },
        });
        errdefer buffer.deinit();

        const bind_group = try bind_group_pool.alloc(bind_group_layout);

        try device.updateBindGroups(.{
            .writes = &.{
                .{
                    .dst = bind_group,
                    .binding = 0xffab,
                    .resource = .{
                        .buffer = .{
                            .buffer = buffer,
                            .size = @sizeOf(Camera.Uniforms),
                        },
                    },
                },
            },
        });

        return .{
            .buffer = buffer,
            .bind_group_pool = bind_group_pool,
            .bind_group_layout = bind_group_layout,
            .bind_group = bind_group,
        };
    }

    pub fn deinit(self: RenderState) void {
        self.bind_group_layout.deinit();
        self.bind_group_pool.deinit();
        self.buffer.deinit();
    }
};

fov: f32 = 70.0,
near: f32 = 0.1,
far: f32 = 100.0,

view: math.Mat4 = math.Mat4.translate(math.vec3(0.0, 0.0, -5.0)),
eye: math.Vec3 = math.vec3(0.0, 0.0, 0.0),

pub fn proj(self: Camera, aspect: f32) math.Mat4 {
    return math.Mat4.projection(
        aspect,
        std.math.degreesToRadians(f32, self.fov),
        self.near,
        self.far,
    );
}

pub fn uniform(self: Camera, aspect: f32) Uniforms {
    return Uniforms{
        .view = self.view.f,
        .proj = self.proj(aspect).f,
        .eye = self.eye.v,
    };
}
