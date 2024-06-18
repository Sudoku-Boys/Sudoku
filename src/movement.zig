const engine = @import("engine.zig");
const std = @import("std");

pub const moveInfo = struct {
    moveSpeed: f32 = 10.0,
    mouseSensitivity: f32 = 1.0,
    window: *engine.Window,
    grabbed: bool = false,
    lastMousePostition: engine.Vec2 = engine.Vec2.ZERO,
    viewDirection: engine.Vec2 = engine.Vec2.ZERO,
};

pub fn moveSystem(
    time: *engine.Time,
    query: engine.Query(struct {
        transform: *engine.Transform,
        moveInfo: *moveInfo,
    }),
) !void {
    var it = query.iterator();
    while (it.next()) |q| {
        var direction = engine.Vec3.ZERO;

        if (q.moveInfo.window.*.isKeyDown('w')) {
            direction.subEq(engine.Vec3.Z);
        }

        if (q.moveInfo.window.*.isKeyDown('s')) {
            direction.addEq(engine.Vec3.Z);
        }

        if (q.moveInfo.window.*.isKeyDown('a')) {
            direction.subEq(engine.Vec3.X);
        }

        if (q.moveInfo.window.*.isKeyDown('d')) {
            direction.addEq(engine.Vec3.X);
        }

        var move = q.transform.rotation.inv().mul(direction);
        move._.y = 0;
        move = move.normalize_or_zero().mul(time.dt * q.moveInfo.moveSpeed);
        q.transform.translation.addEq(move);

        //moving the view with the mouse
        const mouseDelta = q.moveInfo.window.*.mousePosition().sub(q.moveInfo.lastMousePostition);
        q.moveInfo.lastMousePostition = q.moveInfo.window.*.mousePosition();

        if (q.moveInfo.window.*.isMouseDown(0)) {
            q.moveInfo.grabbed = true;
            q.moveInfo.window.*.cursorDisabled();
        } else if (q.moveInfo.window.*.isKeyDown(engine.Window.glfw.GLFW_KEY_ESCAPE)) {
            q.moveInfo.grabbed = false;
            q.moveInfo.window.*.cursorNormal();
        }

        if (q.moveInfo.grabbed) {
            q.moveInfo.viewDirection = q.moveInfo.viewDirection.add(mouseDelta.mul(q.moveInfo.mouseSensitivity * 0.001));

            const rotX = engine.Quat.rotateY(q.moveInfo.viewDirection._.x);
            const rotY = engine.Quat.rotateX(q.moveInfo.viewDirection._.y);

            q.transform.rotation = rotY.mul(rotX);
        }
    }
}
