const std = @import("std");

const World = @import("World.zig");

pub fn Res(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const SystemParamState = void;

        ptr: *T,

        pub fn systemParamInit(world: *World) !SystemParamState {
            _ = world;

            return {};
        }

        pub fn systemParamFetch(world: *World, state: SystemParamState) !Self {
            _ = state;

            return .{
                .ptr = world.resourcePtr(T),
            };
        }

        pub fn get(self: Self) T {
            return self.ptr.*;
        }

        pub fn set(self: Self, value: T) void {
            self.ptr.* = value;
        }
    };
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
            .type = Param.SystemParamState,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };

        param_fields = param_fields ++ .{param_field};
        state_fields = state_fields ++ .{state_field};
    }

    const Params = @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = param_fields,
            .decls = &.{},
            .is_tuple = true,
        },
    });

    const State = @Type(.{
        .Struct = .{
            .layout = .Auto,
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
                const param_state = try Param.systemParamInit(world);
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
                const state = @field(self.state.?, state_name);

                const name = std.fmt.comptimePrint("{}", .{i});
                @field(params, name) = try Param.systemParamFetch(world, state);
            }

            try @call(.auto, f, params);
        }

        pub fn deinit(self: *Self) void {
            if (self.state) |state| {
                inline for (func.params, 0..) |param, i| {
                    const Param = param.type.?;
                    const state_name = std.fmt.comptimePrint("state_{}", .{i});
                    const param_state = @field(state, state_name);

                    if (@hasDecl(Param, "systemParamDeinit")) {
                        Param.systemParamDeinit(param_state);
                    }
                }
            }
        }
    };
}
