const std = @import("std");

const Resources = @This();

const Entry = struct {
    data: *u8,
    deinit_data: *const fn (*u8, std.mem.Allocator) void,

    pub fn deinit(self: Entry, allocator: std.mem.Allocator) void {
        self.deinit_data(self.data, allocator);
    }
};

allocator: std.mem.Allocator,
entries: std.AutoHashMapUnmanaged(std.builtin.TypeId, Entry),

pub fn init(allocator: std.mem.Allocator) Resources {
    return .{
        .allocator = allocator,
        .entries = .{},
    };
}

pub fn deinit(self: *Resources) void {
    var entries = self.entries.valueIterator();
    while (entries.next()) |entry| {
        entry.deinit(self.allocator);
    }

    self.entries.deinit(self.allocator);
}

pub fn contains(self: Resources, comptime T: type) bool {
    const type_id = std.meta.activeTag(@typeInfo(T));
    return self.entries.contains(type_id);
}

fn hasDeinit(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Struct, .Enum, .Union, .Opaque => {},
        else => return false,
    }

    return @hasDecl(T, "deinit");
}

pub fn add(self: *Resources, resource: anytype) !void {
    const T = @TypeOf(resource);
    const type_id = std.meta.activeTag(@typeInfo(T));

    const Closure = struct {
        fn deinit(data: *u8, allocator: std.mem.Allocator) void {
            const data_ptr: *T = @ptrCast(@alignCast(data));

            if (comptime hasDeinit(T)) {
                data_ptr.deinit();
            }

            if (@sizeOf(T) > 0) {
                allocator.destroy(data_ptr);
            }
        }
    };

    var data: *T = undefined;

    if (@sizeOf(T) > 0) {
        data = try self.allocator.create(T);
        data.* = resource;
    }

    const entry = Entry{
        .data = @ptrCast(@alignCast(data)),
        .deinit_data = &Closure.deinit,
    };

    try self.entries.put(self.allocator, type_id, entry);
}

pub fn get(self: Resources, comptime T: type) ?*T {
    const type_id = std.meta.activeTag(@typeInfo(T));
    const entry = self.entries.get(type_id) orelse return null;

    return @ptrCast(@alignCast(entry.data));
}
