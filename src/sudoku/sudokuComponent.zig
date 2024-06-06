const engine = @import("../engine.zig");

pub const Rotate = struct {};

//Placeholder
pub fn testSystem(
    time: *engine.Time,
    query: engine.Query(struct {
        transform: *engine.Transform,
        rotate: *Rotate,
    }),
) !void {
    var it = query.iterator();
    while (it.next()) |q| {
        q.transform.rotation.mulEq(engine.Quat.rotateY(time.dt * 0.2));
    }
}
