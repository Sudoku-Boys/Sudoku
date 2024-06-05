const engine = @import("../engine.zig");

pub const sudokuInfo = struct {};

//Placeholder
pub fn sudokuSystem(
    time: *engine.Time,
    query: engine.Query(struct {
        transform: *engine.Transform,
        sudokuInfo: *sudokuInfo,
    }),
) !void {
    var it = query.iterator();
    while (it.next()) |q| {
        q.transform.rotation.mulEq(engine.Quat.rotateY(time.dt * 0.2));
    }
}
