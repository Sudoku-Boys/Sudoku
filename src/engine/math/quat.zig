const std = @import("std");
const trig = @import("trig.zig");
const vec = @import("vec.zig");
const mat4 = @import("mat4.zig");

const Vec3 = vec.Vec3;
const Mat4 = mat4.Mat4;

pub const Quat = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 1.0,

    pub const IDENTITY: Quat = .{};

    pub fn rotateX(angle: f32) Quat {
        const halfAngle = angle / 2.0;
        const sinHalfAngle = trig.sin(halfAngle);
        const cosHalfAngle = trig.cos(halfAngle);

        const quat: Quat = .{
            .x = sinHalfAngle,
            .y = 0.0,
            .z = 0.0,
            .w = cosHalfAngle,
        };

        // trig is not very precise, so we need to normalize the result
        return quat.normalize();
    }

    pub fn rotateY(angle: f32) Quat {
        const halfAngle = angle / 2.0;
        const sinHalfAngle = trig.sin(halfAngle);
        const cosHalfAngle = trig.cos(halfAngle);

        const quat: Quat = .{
            .x = 0.0,
            .y = sinHalfAngle,
            .z = 0.0,
            .w = cosHalfAngle,
        };

        // trig is not very precise, so we need to normalize the result
        return quat.normalize();
    }

    pub fn rotateZ(angle: f32) Quat {
        const halfAngle = angle / 2.0;
        const sinHalfAngle = trig.sin(halfAngle);
        const cosHalfAngle = trig.cos(halfAngle);

        const quat: Quat = .{
            .x = 0.0,
            .y = 0.0,
            .z = sinHalfAngle,
            .w = cosHalfAngle,
        };

        // trig is not very precise, so we need to normalize the result
        return quat.normalize();
    }

    pub fn rotate(axis: Vec3, angle: f32) Quat {
        const halfAngle = angle / 2.0;
        const sinHalfAngle = trig.sin(halfAngle);
        const cosHalfAngle = trig.cos(halfAngle);

        const quat: Quat = .{
            .x = axis._.x * sinHalfAngle,
            .y = axis._.y * sinHalfAngle,
            .z = axis._.z * sinHalfAngle,
            .w = cosHalfAngle,
        };

        // trig is not very precise, so we need to normalize the result
        return quat.normalize();
    }

    fn MulReturnType(comptime T: type) type {
        if (T == Quat) return Quat;
        if (T == Vec3) return Vec3;

        @compileError("Unsupported type");
    }

    pub fn mul(self: Quat, other: anytype) MulReturnType(@TypeOf(other)) {
        if (@TypeOf(other) == Quat) return self.mulQuat(other);
        if (@TypeOf(other) == Vec3) return self.mulVec3(other);

        @compileError("Unsupported type");
    }

    pub fn mulQuat(self: Quat, other: Quat) Quat {
        return .{
            .x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
            .y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
            .z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
            .w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
        };
    }

    pub fn normalize(self: Quat) Quat {
        const norm = std.math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
        return .{
            .x = self.x / norm,
            .y = self.y / norm,
            .z = self.z / norm,
            .w = self.w / norm,
        };
    }

    pub fn inv(self: Quat) Quat {
        const invNorm = 1.0 / (self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
        return .{
            .x = -self.x * invNorm,
            .y = -self.y * invNorm,
            .z = -self.z * invNorm,
            .w = self.w * invNorm,
        };
    }

    pub fn mulVec3(self: Quat, v: Vec3) Vec3 {
        const x2 = self.x * self.x;
        const y2 = self.y * self.y;
        const z2 = self.z * self.z;
        const xy = self.x * self.y;
        const xz = self.x * self.z;
        const yz = self.y * self.z;
        const wx = self.w * self.x;
        const wy = self.w * self.y;
        const wz = self.w * self.z;

        const x = v._.x;
        const y = v._.y;
        const z = v._.z;

        return .{
            ._ = .{
                .x = (1.0 - 2.0 * (y2 + z2)) * x + (2.0 * (xy - wz)) * y + (2.0 * (xz + wy)) * z,
                .y = (2.0 * (xy + wz)) * x + (1.0 - 2.0 * (x2 + z2)) * y + (2.0 * (yz - wx)) * z,
                .z = (2.0 * (xz - wy)) * x + (2.0 * (yz + wx)) * y + (1.0 - 2.0 * (x2 + y2)) * z,
            },
        };
    }

    pub fn asMat4(self: Quat) Mat4 {
        const x2 = self.x * self.x;
        const y2 = self.y * self.y;
        const z2 = self.z * self.z;
        const xy = self.x * self.y;
        const xz = self.x * self.z;
        const yz = self.y * self.z;
        const wx = self.w * self.x;
        const wy = self.w * self.y;
        const wz = self.w * self.z;

        return .{
            ._ = .{
                .m00 = 1.0 - 2.0 * (y2 + z2),
                .m01 = 2.0 * (xy - wz),
                .m02 = 2.0 * (xz + wy),
                .m03 = 0.0,
                .m10 = 2.0 * (xy + wz),
                .m11 = 1.0 - 2.0 * (x2 + z2),
                .m12 = 2.0 * (yz - wx),
                .m13 = 0.0,
                .m20 = 2.0 * (xz - wy),
                .m21 = 2.0 * (yz + wx),
                .m22 = 1.0 - 2.0 * (x2 + y2),
                .m23 = 0.0,
                .m30 = 0.0,
                .m31 = 0.0,
                .m32 = 0.0,
                .m33 = 1.0,
            },
        };
    }
};
