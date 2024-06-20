const engine = @import("engine.zig");
const std = @import("std");

pub const PlayerMovement = struct {
    moveSpeed: f32 = 3.0,
    mouseSensitivity: f32 = 1.0,
    window: *engine.Window,
    grabbed: bool = false,
    lastMousePostition: engine.Vec2 = engine.Vec2.ZERO,
    viewDirection: engine.Vec2 = engine.Vec2.ZERO,
    time_moved: f32 = 0.0,
};

pub fn moveSystem(
    time: *engine.Time,
    query: engine.Query(struct {
        transform: *engine.Transform,
        movement: *PlayerMovement,
    }),
) !void {
    var it = query.iterator();
    while (it.next()) |q| {
        var direction = engine.Vec3.ZERO;

        if (q.movement.window.isKeyDown('w')) {
            direction.subEq(engine.Vec3.Z);
        }

        if (q.movement.window.isKeyDown('s')) {
            direction.addEq(engine.Vec3.Z);
        }

        if (q.movement.window.isKeyDown('a')) {
            direction.subEq(engine.Vec3.X);
        }

        if (q.movement.window.isKeyDown('d')) {
            direction.addEq(engine.Vec3.X);
        }

        var move = q.transform.rotation.inv().mul(direction);
        move._.y = 0;
        move = move.normalize_or_zero().mul(time.dt * q.movement.moveSpeed);
        q.transform.translation.addEq(move);

        if (move.len() > 0.0) {
            q.movement.time_moved += time.dt;
        } else {
            q.movement.time_moved = 0.0;
        }

        //moving the view with the mouse
        const mouseDelta = q.movement.window.mousePosition().sub(q.movement.lastMousePostition);
        q.movement.lastMousePostition = q.movement.window.mousePosition();

        if (q.movement.window.isMouseDown(0)) {
            q.movement.grabbed = true;
            q.movement.window.*.cursorDisabled();
        } else if (q.movement.window.isKeyDown(engine.Window.glfw.GLFW_KEY_ESCAPE)) {
            q.movement.grabbed = false;
            q.movement.window.*.cursorNormal();
        }

        if (q.movement.grabbed) {
            q.movement.viewDirection = q.movement.viewDirection.add(
                mouseDelta.mul(q.movement.mouseSensitivity * 0.001),
            );

            q.movement.viewDirection._.y = std.math.clamp(
                q.movement.viewDirection._.y,
                -0.1,
                0.1,
            );

            const rotX = engine.Quat.rotateY(q.movement.viewDirection._.x);
            const rotY = engine.Quat.rotateX(q.movement.viewDirection._.y);

            q.transform.rotation = rotY.mul(rotX);
        }

        // bobbing
        q.transform.translation._.y = 2 + @sin(q.movement.time_moved * 7.0) * 0.05;
    }
}
