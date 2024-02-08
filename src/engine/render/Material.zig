const std = @import("std");
const vk = @import("vulkan");

const Material = @This();

pub const Context = struct {
    allocator: *std.mem.Allocator,
    device: *vk.Device,
    staging_buffer: *vk.StagingBuffer,
};

pub const VTable = struct {
    alloc_state: *const fn (std.mem.Allocator) anyerror!*anyopaque,
    free_state: *const fn (std.mem.Allocator, *anyopaque) void,
    bind_group_layout_entries: *const fn () []const vk.BindGroupLayout.Entry,

    init_state: *const fn (*anyopaque, Context, vk.BindGroup) anyerror!void,
    deinit_state: *const fn (*anyopaque) void,
    update: *const fn (*anyopaque, *anyopaque, Context) anyerror!void,
};

vtable: *const VTable,
type_id: std.builtin.TypeId,

pub fn init(comptime T: type) Material {
    const State = T.State;
    _ = State;

    return .{
        .vtable = &VTable{
            .alloc_state = Opaque(T).allocState,
            .free_state = Opaque(T).freeState,
            .init_state = Opaque(T).initState,

            .deinit_state = Opaque(T).deinitState,
            .bind_group_layout_entries = Opaque(T).bindGroupLayoutEntries,
            .update = Opaque(T).update,
        },
        .type_id = std.meta.activeTag(@typeInfo(T)),
    };
}

fn Opaque(comptime T: type) type {
    const State = T.State;

    return struct {
        fn allocState(allocator: std.mem.Allocator) !*anyopaque {
            return try allocator.create(State);
        }

        fn freeState(allocator: std.mem.Allocator, state: *anyopaque) void {
            const state_ptr: *State = @ptrCast(@alignCast(state));
            allocator.destroy(state_ptr);
        }

        fn bindGroupLayoutEntries() []const vk.BindGroupLayout.Entry {
            return T.bindGroupLayoutEntries();
        }

        fn initState(
            state: *anyopaque,
            cx: Context,
            bind_group: vk.BindGroup,
        ) anyerror!void {
            const state_ptr: *State = @ptrCast(@alignCast(state));
            state_ptr.* = try T.initState(cx, bind_group);
        }

        fn deinitState(state: *anyopaque) void {
            const state_ptr: *State = @ptrCast(@alignCast(state));
            T.deinitState(state_ptr);
        }

        fn update(material: *anyopaque, state: *anyopaque, cx: Context) anyerror!void {
            const material_ptr: *T = @ptrCast(@alignCast(material));
            const state_ptr: *State = @ptrCast(@alignCast(state));
            try material_ptr.update(state_ptr, cx);
        }
    };
}

pub fn allocState(self: Material, allocator: std.mem.Allocator) !*anyopaque {
    return self.vtable.alloc_state(allocator);
}

pub fn freeState(self: Material, allocator: std.mem.Allocator, state: *anyopaque) void {
    self.vtable.free_state(allocator, state);
}

pub fn bindGroupLayoutEntries(self: Material) []const vk.BindGroupLayout.Entry {
    return self.vtable.bind_group_layout_entries();
}

pub fn initState(
    self: Material,
    state: *anyopaque,
    cx: Context,
    bind_group: vk.BindGroup,
) anyerror!void {
    try self.vtable.init_state(state, cx, bind_group);
}

pub fn deinitState(self: Material, state: *anyopaque) void {
    self.vtable.deinit_state(state);
}

pub fn update(
    self: Material,
    material: *anyopaque,
    state: *anyopaque,
    cx: Context,
    bind_group: vk.BindGroup,
) anyerror!void {
    _ = bind_group;
    try self.vtable.update(material, state, cx);
}
