const TypeId = @This();

id: usize,

// from https://github.com/ziglang/zig/issues/5459
pub fn of(comptime T: type) TypeId {
    _ = T;

    const id = @intFromPtr(&struct {
        var x: u8 = 0;
    }.x);

    return .{
        .id = id,
    };
}
