const std = @import("std");
const World = @import("World.zig");

pub const AccessKind = enum {
    Read,
    Write,

    pub fn isCompatible(self: AccessKind, other: AccessKind) bool {
        return self == .Read and other == .Read;
    }
};

pub const DataKind = enum {
    Component,
    Resource,
};

pub const Access = struct {
    kind: AccessKind,
    data: DataKind,
    type: std.builtin.TypeId,

    pub fn init(comptime T: type, kind: AccessKind, data: DataKind) Access {
        return .{
            .kind = kind,
            .data = data,
            .type = std.meta.activeTag(@typeInfo(T)),
        };
    }

    pub fn isCompatible(self: Access, other: Access) bool {
        return self.kind.isCompatible(other.kind) or
            self.type != other.type or
            self.data != other.data;
    }

    pub fn isSetCompatible(self: Access, other: []const Access) bool {
        for (other) |access| {
            if (!self.isCompatible(access)) return false;
        }

        return true;
    }

    pub fn areSetsCompatible(self: []const Access, other: []const Access) bool {
        for (self) |access| {
            if (!access.isSetCompatible(other)) return false;
        }

        return true;
    }
};

fn systemStruct(comptime system: anytype) type {
    const T = @TypeOf(system);
    const info = @typeInfo(T);

    if (info != .Fn) @compileError("System must be a function");

    comptime var params: [info.Fn.params.len]std.builtin.Type.StructField = undefined;
    comptime var access: []const Access = &.{};

    for (info.Fn.params, 0..) |param, i| {
        if (param.type == null) @compileError("System parameters must have a type");
        if (!@hasDecl(param.type.?, "systemFetch")) {
            @compileError("System parameters must have a `systemFetch` method");
        }

        const param_type = param.type.?;

        if (!@hasDecl(param_type, "ACCESS")) {
            @compileError("System parameters must have an `ACCESS` field");
        }

        const param_access = @field(param_type, "ACCESS");

        if (!Access.areSetsCompatible(access, param_access)) {
            @compileError("System parameters must have compatible access");
        }

        access = access ++ param_access;

        params[i] = .{
            .name = std.fmt.comptimePrint("{}", .{i}),
            .type = param.type.?,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    const State = @Type(.{ .Struct = .{
        .layout = .Auto,
        .backing_integer = null,
        .fields = &params,
        .decls = &.{},
        .is_tuple = true,
    } });

    return struct {
        pub const ACCESS: []const Access = access;

        pub fn run(world: *World) !void {
            var state: State = undefined;

            inline for (info.Fn.params, 0..) |param, i| {
                const field = std.fmt.comptimePrint("{}", .{i});
                const fetch = @field(param.type.?, "systemFetch");
                @field(state, field) = try fetch(world);
            }

            try @call(.auto, system, state);
        }
    };
}

pub const System = struct {
    access: []const Access,
    run: *const fn (*World) anyerror!void,

    pub fn init(comptime system: anytype) System {
        const S = systemStruct(system);

        return .{
            .access = S.ACCESS,
            .run = S.run,
        };
    }

    pub fn run(self: System, world: *World) !void {
        try (self.run)(world);
    }
};
