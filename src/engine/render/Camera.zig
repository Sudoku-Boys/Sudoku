const std = @import("std");
const vk = @import("vulkan");
const math = @import("../math.zig");

const Transform = @import("../Transform.zig");

const Camera = @This();

pub const Uniforms = extern struct {
    view: [16]f32,
    proj: [16]f32,
    view_proj: [16]f32,
    inv_view_proj: [16]f32,
    eye: [3]f32,
    _padding0: [4]u8 = undefined,
};

fov: f32 = 70.0,
near: f32 = 0.1,
far: f32 = 100.0,

transform: Transform = Transform.xyz(0.0, 0.0, 5.0),

pub fn proj(self: Camera, aspect: f32) math.Mat4 {
    return math.Mat4.projection(
        aspect,
        self.fov / 360.0,
        self.near,
        self.far,
    );
}

pub fn uniforms(self: Camera, aspect: f32) Uniforms {
    const view_matrix = self.transform.computeMatrix();
    const proj_matrix = self.proj(aspect);
    const view_proj_matrix = view_matrix.inv().mul(proj_matrix);
    const inv_view_proj_matrix = view_proj_matrix.inv();

    const eye = self.transform.translation;

    return Uniforms{
        .view = view_matrix.f,
        .proj = proj_matrix.f,
        .view_proj = view_proj_matrix.f,
        .inv_view_proj = inv_view_proj_matrix.f,
        .eye = eye.swizzle("xyz").v,
    };
}
