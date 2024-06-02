const TypeId = @This();

id: usize,

// from https://github.com/ziglang/zig/issues/5459
pub fn of(comptime T: type) TypeId {
    const id = @intFromPtr(&struct {
        var x: u8 = 0;

        v: T = undefined,
    }.x);

    return .{
        .id = id,
    };
}

pub fn eql(a: TypeId, b: TypeId) bool {
    return a.id == b.id;
}
