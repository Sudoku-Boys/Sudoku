const math = @import("math.zig");

const Transform = @import("Transform.zig");

const GlobalTransform = @This();

translation: math.Vec3 = math.Vec3.ZERO,
rotation: math.Quat = math.Quat.IDENTITY,
scale: math.Vec3 = math.Vec3.ONE,

pub fn transformPoint(self: GlobalTransform, point: math.Vec3) math.Vec3 {
    var p = self.scale.mul(point);
    p = self.rotation.inv().mul(p);
    p = self.translation.add(p);

    return p;
}

pub fn transform(self: GlobalTransform, t: Transform) GlobalTransform {
    const translation = self.transformPoint(t.translation);
    const rotation = self.rotation.mul(t.rotation);
    const scale = self.scale.mul(t.scale);

    return .{
        .translation = translation,
        .rotation = rotation,
        .scale = scale,
    };
}

pub fn computeMatrix(self: GlobalTransform) math.Mat4 {
    var matrix = math.Mat4.scale(self.scale);
    matrix = matrix.mul(self.rotation.asMat4());
    matrix = matrix.mul(math.Mat4.translate(self.translation));

    return matrix;
}
