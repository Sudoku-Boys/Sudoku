const std = @import("std");

const World = @import("World.zig");

fn SystemParamState(comptime T: type) type {
    const type_info = @typeInfo(T);

    if (T == std.mem.Allocator) return void;

    switch (type_info) {
        .Pointer => return void,
        else => return T.SystemParamState,
    }
}

fn systemParamInit(comptime T: type, world: *World) !SystemParamState(T) {
    const type_info = @typeInfo(T);

    if (T == std.mem.Allocator) return;

    switch (type_info) {
        .Pointer => {},
        else => return T.systemParamInit(world),
    }
}

pub fn systemParamFetch(comptime T: type, world: *World, state: *SystemParamState(T)) !T {
    const type_info = @typeInfo(T);

    if (T == std.mem.Allocator) return world.allocator;

    switch (type_info) {
        .Pointer => |pointer| return world.resourcePtrOrInit(pointer.child),
        else => return T.systemParamFetch(world, state),
    }
}

pub fn systemParamApply(comptime T: type, world: *World, state: *SystemParamState(T)) !void {
    const type_info = @typeInfo(T);

    if (T == std.mem.Allocator) return;

    switch (type_info) {
        .Pointer => {},
        else => try T.systemParamApply(world, state),
    }
}

pub fn systemParamDeinit(comptime T: type, state: *SystemParamState(T)) void {
    const type_info = @typeInfo(T);

    if (T == std.mem.Allocator) return;

    switch (type_info) {
        .Pointer => {},
        .Struct, .Enum, .Union, .Opaque => if (@hasDecl(T, "systemParamDeinit")) {
            T.systemParamDeinit(state);
        },
        else => {},
    }
}

pub fn FunctionSystem(comptime f: anytype) type {
    const T = @TypeOf(f);

    if (@typeInfo(T) != .Fn) {
        @compileError("FunctionSystem requires a function type");
    }

    const func = @typeInfo(T).Fn;

    comptime var param_fields: []const std.builtin.Type.StructField = &.{};
    comptime var state_fields: []const std.builtin.Type.StructField = &.{};

    for (func.params, 0..) |param, i| {
        const Param = param.type.?;

        const name = std.fmt.comptimePrint("{}", .{i});
        const param_field = std.builtin.Type.StructField{
            .name = name,
            .type = Param,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };

        const state_name = std.fmt.comptimePrint("state_{}", .{i});
        const state_field = std.builtin.Type.StructField{
            .name = state_name,
            .type = SystemParamState(Param),
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };

        param_fields = param_fields ++ .{param_field};
        state_fields = state_fields ++ .{state_field};
    }

    const Params = @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = param_fields,
            .decls = &.{},
            .is_tuple = true,
        },
    });

    const State = @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = state_fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });

    return struct {
        const Self = @This();

        state: ?State = null,

        fn init(self: *Self, world: *World) !void {
            var state: State = undefined;

            inline for (func.params, 0..) |param, i| {
                const Param = param.type.?;
                const name = std.fmt.comptimePrint("state_{}", .{i});
                const param_state = try systemParamInit(Param, world);
                @field(state, name) = param_state;
            }

            self.state = state;
        }

        pub fn run(self: *Self, world: *World) !void {
            if (self.state == null) try self.init(world);

            var params: Params = undefined;

            inline for (func.params, 0..) |param, i| {
                const Param = param.type.?;

                const state_name = std.fmt.comptimePrint("state_{}", .{i});
                const state = &@field(self.state.?, state_name);

                const name = std.fmt.comptimePrint("{}", .{i});
                @field(params, name) = try systemParamFetch(Param, world, state);
            }

            try @call(.auto, f, params);
        }

        pub fn apply(self: *Self, world: *World) !void {
            if (self.state == null) try self.init(world);

            inline for (func.params, 0..) |param, i| {
                const Param = param.type.?;

                const state_name = std.fmt.comptimePrint("state_{}", .{i});
                const state = &@field(self.state.?, state_name);

                try systemParamApply(Param, world, state);
            }
        }

        pub fn deinit(self: *Self) void {
            if (self.state) |*state| {
                inline for (func.params, 0..) |param, i| {
                    const Param = param.type.?;
                    const state_name = std.fmt.comptimePrint("state_{}", .{i});
                    const param_state = &@field(state, state_name);

                    systemParamDeinit(Param, param_state);
                }
            }
        }
    };
}
