const math = @import("math.zig");

const Transform = @This();

translation: math.Vec3 = math.Vec3.ZERO,
rotation: math.Quat = math.Quat.IDENTITY,
scale: math.Vec3 = math.Vec3.ONE,

pub fn xyz(x: f32, y: f32, z: f32) Transform {
    return .{
        .translation = math.vec3(x, y, z),
    };
}

pub fn computeMatrix(self: Transform) math.Mat4 {
    var matrix = math.Mat4.scale(self.scale);
    matrix = matrix.mul(self.rotation.asMat4());
    matrix = matrix.mul(math.Mat4.translate(self.translation));

    return matrix;
}
