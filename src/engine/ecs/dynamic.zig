const std = @import("std");

pub fn deinitFn(comptime T: type) ?*const fn (*anyopaque) void {
    switch (@typeInfo(T)) {
        .Struct => {},
        .Enum => {},
        .Union => {},
        .Opaque => {},
        else => return null,
    }

    if (!@hasDecl(T, "deinit")) return null;

    const deinit = @field(T, "deinit");

    if (@typeInfo(@TypeOf(deinit)) != .Fn) @compileError("deinit must be a function");

    const deinit_type = @typeInfo(@TypeOf(deinit)).Fn;

    if (deinit_type.return_type != void) @compileError("deinit must return void");
    if (deinit_type.params.len != 1) @compileError("deinit must take one a self parameter");
    if (deinit_type.params[0].type == null) @compileError("deinit must take one a self parameter");

    const self_type = deinit_type.params[0].type.?;

    if (self_type == T) {
        const wrapper = struct {
            fn deinitWrapper(any: *anyopaque) void {
                const ptr: *T = @ptrCast(@alignCast(any));
                deinit(ptr.*);
            }
        };

        return wrapper.deinitWrapper;
    }

    if (self_type != .Pointer or self_type.Pointer.Child != T) {
        @compileError("deinit must take either a self parameter or a pointer to self parameter");
    }

    const wrapper = struct {
        fn deinitWrapper(any: *anyopaque) void {
            deinit(@ptrCast(@alignCast(any)));
        }
    };

    return wrapper.deinitWrapper;
}
