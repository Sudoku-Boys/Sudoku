const std = @import("std");

const intrinsic = @import("simd.zig");
const trig = @import("trig.zig");
const vec = @import("vec.zig");

const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;

pub fn mat4(r0: @Vector(4, f32), r1: @Vector(4, f32), r2: @Vector(4, f32), r3: @Vector(4, f32)) Mat4 {
    return Mat4.init(r0, r1, r2, r3);
}

pub const Mat4 = extern union {
    _: extern struct {
        m00: f32,
        m01: f32,
        m02: f32,
        m03: f32,
        m10: f32,
        m11: f32,
        m12: f32,
        m13: f32,
        m20: f32,
        m21: f32,
        m22: f32,
        m23: f32,
        m30: f32,
        m31: f32,
        m32: f32,
        m33: f32,
    },
    f: [16]f32,
    v: [4]@Vector(4, f32),

    pub const IDENTITY: Mat4 = .{
        ._ = .{
            .m00 = 1.0,
            .m01 = 0.0,
            .m02 = 0.0,
            .m03 = 0.0,
            .m10 = 0.0,
            .m11 = 1.0,
            .m12 = 0.0,
            .m13 = 0.0,
            .m20 = 0.0,
            .m21 = 0.0,
            .m22 = 1.0,
            .m23 = 0.0,
            .m30 = 0.0,
            .m31 = 0.0,
            .m32 = 0.0,
            .m33 = 1.0,
        },
    };

    pub fn init(r0: @Vector(4, f32), r1: @Vector(4, f32), r2: @Vector(4, f32), r3: @Vector(4, f32)) Mat4 {
        return Mat4{ .v = .{ r0, r1, r2, r3 } };
    }

    pub inline fn projection(aspectRatio: f32, fov: f32, near: f32, far: f32) Mat4 {
        var mat: Mat4 = IDENTITY;

        const sc: f32 = std.math.atan(fov * 0.5 * 2 * std.math.pi);
        mat._.m00 = 1.0 / (sc * aspectRatio);
        mat._.m11 = 1.0 / (sc);
        mat._.m22 = -(far + near) / (far - near);
        mat._.m23 = -1.0;
        mat._.m32 = -(2.0 * far * near) / (far - near);
        mat._.m33 = 0;

        return mat;
    }

    pub inline fn translate(tr: Vec3) Mat4 {
        var mat: Mat4 = IDENTITY;

        mat._.m30 = tr._.x;
        mat._.m31 = tr._.y;
        mat._.m32 = tr._.z;

        return mat;
    }

    pub inline fn scale(sc: Vec3) Mat4 {
        var mat: Mat4 = IDENTITY;

        mat._.m00 = sc._.x;
        mat._.m11 = sc._.y;
        mat._.m22 = sc._.z;

        return mat;
    }

    pub inline fn rotateX(angle: f32) Mat4 {
        var mat: Mat4 = IDENTITY;

        const c = trig.fcos(angle);
        const s = trig.fsin(angle);

        mat._.m11 = c;
        mat._.m12 = s;
        mat._.m21 = -s;
        mat._.m22 = c;

        return mat;
    }

    pub inline fn rotateY(angle: f32) Mat4 {
        var mat: Mat4 = IDENTITY;

        const c = trig.fcos(angle);
        const s = trig.fsin(angle);

        mat._.m00 = c;
        mat._.m02 = -s;
        mat._.m20 = s;
        mat._.m22 = c;

        return mat;
    }

    pub inline fn rotateZ(angle: f32) Mat4 {
        var mat: Mat4 = IDENTITY;

        const c = trig.fcos(angle);
        const s = trig.fsin(angle);

        mat._.m00 = c;
        mat._.m01 = s;
        mat._.m10 = -s;
        mat._.m11 = c;

        return mat;
    }

    pub inline fn rotate(axis: Vec3, angle: f32) Mat4 {
        var mat: Mat4 = IDENTITY;

        const c = trig.cos(angle);
        const s = trig.sin(angle);
        const ic = 1 - c;

        mat._.m00 = axis._.x * axis._.x * ic + c;
        mat._.m01 = axis._.x * axis._.y * ic + axis._.z * s;
        mat._.m02 = axis._.x * axis._.z * ic - axis._.y * s;

        mat._.m10 = axis._.y * axis._.x * ic - axis._.z * s;
        mat._.m11 = axis._.y * axis._.y * ic + c;
        mat._.m12 = axis._.y * axis._.z * ic + axis._.x * s;

        mat._.m20 = axis._.z * axis._.x * ic + axis._.y * s;
        mat._.m21 = axis._.z * axis._.y * ic - axis._.x * s;
        mat._.m22 = axis._.z * axis._.z * ic + c;

        return mat;
    }

    pub inline fn addf(a: Mat4, b: f32) Mat4 {
        const broad = @Vector(4, f32){ b, b, b, b };

        return Mat4{
            .v = .{
                a.v[0] + broad,
                a.v[1] + broad,
                a.v[2] + broad,
                a.v[3] + broad,
            },
        };
    }

    pub inline fn subf(a: Mat4, b: f32) Mat4 {
        const broad = @Vector(4, f32){ b, b, b, b };

        return Mat4{
            .v = .{
                a.v[0] - broad,
                a.v[1] - broad,
                a.v[2] - broad,
                a.v[3] - broad,
            },
        };
    }

    pub inline fn mulf(a: Mat4, b: f32) Mat4 {
        const broad = @Vector(4, f32){ b, b, b, b };

        return Mat4{
            .v = .{
                a.v[0] * broad,
                a.v[1] * broad,
                a.v[2] * broad,
                a.v[3] * broad,
            },
        };
    }

    pub inline fn divf(a: Mat4, b: f32) Mat4 {
        const broad = @Vector(4, f32){ b, b, b, b };

        return Mat4{
            .v = .{
                a.v[0] / broad,
                a.v[1] / broad,
                a.v[2] / broad,
                a.v[3] / broad,
            },
        };
    }

    pub inline fn iden() Mat4 {
        return Mat4{
            .v = .{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub inline fn trans(a: Mat4) Mat4 {
        const r0 = a.v[0];
        const r1 = a.v[1];
        const r2 = a.v[2];
        const r3 = a.v[3];

        const tr01a = intrinsic.unpacklo(r0, r1);
        const tr23a = intrinsic.unpacklo(r2, r3);
        const tr01b = intrinsic.unpackhi(r0, r1);
        const tr23b = intrinsic.unpackhi(r2, r3);

        return Mat4{
            .v = .{
                intrinsic.movelh(tr01a, tr23a),
                intrinsic.movehl(tr23a, tr01a),
                intrinsic.movelh(tr01b, tr23b),
                intrinsic.movehl(tr23b, tr01b),
            },
        };
    }

    pub inline fn inv(a: Mat4) Mat4 {

        // load input matrix
        const r0 = a.v[0];
        const r1 = a.v[1];
        const r2 = a.v[2];
        const r3 = a.v[3];

        // perute into intermediary groups
        const im01 = intrinsic.permute(r0, .{ 1, 0, 0, 0 });
        const im02 = intrinsic.permute(r0, .{ 2, 2, 1, 1 });
        const im03 = intrinsic.permute(r0, .{ 3, 3, 3, 2 });

        const im11 = intrinsic.permute(r1, .{ 1, 0, 0, 0 });
        const im12 = intrinsic.permute(r1, .{ 2, 2, 1, 1 });
        const im13 = intrinsic.permute(r1, .{ 3, 3, 3, 2 });

        const im21 = intrinsic.permute(r2, .{ 1, 0, 0, 0 });
        const im22 = intrinsic.permute(r2, .{ 2, 2, 1, 1 });
        const im23 = intrinsic.permute(r2, .{ 3, 3, 3, 2 });

        const im31 = intrinsic.permute(r3, .{ 1, 0, 0, 0 });
        const im32 = intrinsic.permute(r3, .{ 2, 2, 1, 1 });
        const im33 = intrinsic.permute(r3, .{ 3, 3, 3, 2 });

        // compute secondary intermediary groups
        const j0 = (im22 * im33) - (im23 * im32);
        const j1 = (im23 * im31) - (im21 * im33);
        const j2 = (im21 * im32) - (im22 * im31);
        const j3 = (im02 * im13) - (im03 * im12);
        const j4 = (im03 * im11) - (im01 * im13);
        const j5 = (im01 * im12) - (im02 * im11);

        // compute matrix of minors
        const m0 = (im11 * j0) + (im12 * j1) + (im13 * j2);
        const m1 = (im01 * j0) + (im02 * j1) + (im03 * j2);
        const m2 = (im31 * j3) + (im32 * j4) + (im33 * j5);
        const m3 = (im21 * j3) + (im22 * j4) + (im23 * j5);

        // calculate determinant intermediary, determinant is [0] - [1] + [2] - [3] of r0 * m0
        const di = r0 * m0;

        // calculate alternating sign inverse determinant for rows 0 and 2
        const rvasid = (intrinsic.permute(di, .{ 0, 1, 0, 1 }) - intrinsic.permute(di, .{ 1, 0, 1, 0 })) +
            (intrinsic.permute(di, .{ 2, 3, 2, 3 }) - intrinsic.permute(di, .{ 3, 2, 3, 2 }));
        const asid0 = asm volatile (
            \\ vrcpps %[av0], %[av1]
            : [av1] "=x" (-> @Vector(4, f32)),
            : [av0] "x" (rvasid),
        );
        // compute alternating sign inverse determinant for rows 1 and 3
        const asid1 = intrinsic.permute(asid0, .{ 1, 0, 1, 0 });

        // calculate matrix of cofactors
        const n0 = m0 * asid0;
        const n1 = m1 * asid1;
        const n2 = m2 * asid0;
        const n3 = m3 * asid1;

        // transpose and store matrix
        const tr01a = intrinsic.unpacklo(n0, n1);
        const tr23a = intrinsic.unpacklo(n2, n3);
        const tr01b = intrinsic.unpackhi(n0, n1);
        const tr23b = intrinsic.unpackhi(n2, n3);

        return Mat4{
            .v = .{
                intrinsic.movelh(tr01a, tr23a),
                intrinsic.movehl(tr23a, tr01a),
                intrinsic.movelh(tr01b, tr23b),
                intrinsic.movehl(tr23b, tr01b),
            },
        };
    }

    pub inline fn add(a: Mat4, b: Mat4) Mat4 {
        return Mat4{
            .v = .{
                a.v[0] + b.v[0],
                a.v[1] + b.v[1],
                a.v[2] + b.v[2],
                a.v[3] + b.v[3],
            },
        };
    }

    pub inline fn sub(a: Mat4, b: Mat4) Mat4 {
        return Mat4{ .v = .{
            a.v[0] - b.v[0],
            a.v[1] - b.v[1],
            a.v[2] - b.v[2],
            a.v[3] - b.v[3],
        } };
    }

    pub inline fn mul(a: Mat4, b: Mat4) Mat4 {

        // load matrix a
        const r0 = a.v[0];
        const r1 = a.v[1];
        const r2 = a.v[2];
        const r3 = a.v[3];

        // load matrix b
        const b0 = b.v[0];
        const b1 = b.v[1];
        const b2 = b.v[2];
        const b3 = b.v[3];

        // transpose matrix a
        const tr01a = intrinsic.unpacklo(r0, r1);
        const tr23a = intrinsic.unpacklo(r2, r3);
        const tr01b = intrinsic.unpackhi(r0, r1);
        const tr23b = intrinsic.unpackhi(r2, r3);

        const t0 = intrinsic.movelh(tr01a, tr23a);
        const t1 = intrinsic.movehl(tr23a, tr01a);
        const t2 = intrinsic.movelh(tr01b, tr23b);
        const t3 = intrinsic.movehl(tr23b, tr01b);

        var o: Mat4 = undefined;

        // first row
        {
            const a0 = (intrinsic.permute(t0, .{ 0, 0, 0, 0 }) * b0) + (intrinsic.permute(t2, .{ 0, 0, 0, 0 }) * b2);
            const a1 = (intrinsic.permute(t1, .{ 0, 0, 0, 0 }) * b1) + (intrinsic.permute(t3, .{ 0, 0, 0, 0 }) * b3);
            o.v[0] = a0 + a1;
        }
        // second row
        {
            const a0 = (intrinsic.permute(t0, .{ 1, 1, 1, 1 }) * b0) + (intrinsic.permute(t2, .{ 1, 1, 1, 1 }) * b2);
            const a1 = (intrinsic.permute(t1, .{ 1, 1, 1, 1 }) * b1) + (intrinsic.permute(t3, .{ 1, 1, 1, 1 }) * b3);
            o.v[1] = a0 + a1;
        }
        // third row
        {
            const a0 = (intrinsic.permute(t0, .{ 2, 2, 2, 2 }) * b0) + (intrinsic.permute(t2, .{ 2, 2, 2, 2 }) * b2);
            const a1 = (intrinsic.permute(t1, .{ 2, 2, 2, 2 }) * b1) + (intrinsic.permute(t3, .{ 2, 2, 2, 2 }) * b3);
            o.v[2] = a0 + a1;
        }
        // fourth row
        {
            const a0 = (intrinsic.permute(t0, .{ 3, 3, 3, 3 }) * b0) + (intrinsic.permute(t2, .{ 3, 3, 3, 3 }) * b2);
            const a1 = (intrinsic.permute(t1, .{ 3, 3, 3, 3 }) * b1) + (intrinsic.permute(t3, .{ 3, 3, 3, 3 }) * b3);
            o.v[3] = a0 + a1;
        }

        return o;
    }

    pub inline fn div(a: Mat4, b: Mat4) Mat4 {
        return mul(a, inv(b));
    }

    /// for the boys that don't know how to matrix math
    /// multiply matrix by vector (as a column)
    /// [4x4] * [4x1] = [4x1]
    pub inline fn mulv(a: Mat4, b: Vec4) Vec4 {
        // load matrix a
        const r0 = a.v[0];
        const r1 = a.v[1];
        const r2 = a.v[2];
        const r3 = a.v[3];

        // transpose matrix a
        const tr01a = intrinsic.unpacklo(r0, r1);
        const tr23a = intrinsic.unpacklo(r2, r3);
        const tr01b = intrinsic.unpackhi(r0, r1);
        const tr23b = intrinsic.unpackhi(r2, r3);

        const t0 = intrinsic.movelh(tr01a, tr23a);
        const t1 = intrinsic.movehl(tr23a, tr01a);
        const t2 = intrinsic.movelh(tr01b, tr23b);
        const t3 = intrinsic.movehl(tr23b, tr01b);

        // permute column vector into rows
        const p0 = intrinsic.permute(b.v, .{ 0, 0, 0, 0 });
        const p1 = intrinsic.permute(b.v, .{ 1, 1, 1, 1 });
        const p2 = intrinsic.permute(b.v, .{ 2, 2, 2, 2 });
        const p3 = intrinsic.permute(b.v, .{ 3, 3, 3, 3 });

        // mathimus maximus
        return Vec4{
            .v = (p0 * t0) + (p1 * t1) + (p2 * t2) + (p3 * t3),
        };
    }
};
