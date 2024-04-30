const std = @import("std");

pub const VTable = struct {
    init: ?*const fn (*u8) anyerror!void,
    deinit: ?*const fn (*u8) void,

    pub const EMPTY: *const VTable = &.{
        .init = null,
        .deinit = null,
    };

    pub fn of(comptime T: type) *const VTable {
        if (@alignOf(T) > 16) {
            @compileError("Components must have an alignment of 16 bytes or less!");
        }

        switch (@typeInfo(T)) {
            .Struct, .Enum, .Union, .Opaque => {},
            else => return EMPTY,
        }

        comptime var vtable = VTable{
            .init = null,
            .deinit = null,
        };

        if (@hasDecl(T, "init")) {
            vtable.init = Closure(T).init;
        }

        if (@hasDecl(T, "deinit")) {
            vtable.deinit = Closure(T).deinit;
        }

        return &vtable;
    }

    fn Closure(comptime T: type) type {
        return struct {
            fn init(component: *u8) anyerror!void {
                _ = component;
            }

            fn deinit(component: *u8) void {
                if (@hasDecl(T, "deinit")) {
                    const ptr: *T = @ptrCast(@alignCast(component));
                    ptr.deinit();
                }
            }
        };
    }
};
