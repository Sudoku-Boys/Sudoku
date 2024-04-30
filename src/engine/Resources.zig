//! Resources is a collection of singletons indexed by their type.
//!
//! Important notes:
//!  - Only one instance of a resource can exist at a time.
//!    If you try to add a resource that already exists, nothing will happen.
//!
//!  - Resources are deinitialized in reverse insertion order. This is important
//!    for avoiding use-after-free bugs. ALWAYS insert resources in order of creation.

const std = @import("std");

const TypeId = @import("TypeId.zig");

const Resources = @This();

const Entry = struct {
    data: *u8,
    deinit_data: *const fn (*u8, std.mem.Allocator) void,

    pub fn deinit(self: Entry, allocator: std.mem.Allocator) void {
        self.deinit_data(self.data, allocator);
    }
};

allocator: std.mem.Allocator,
entries: std.AutoHashMapUnmanaged(TypeId, Entry),
order: std.ArrayListUnmanaged(TypeId),

pub fn init(allocator: std.mem.Allocator) Resources {
    return .{
        .allocator = allocator,
        .entries = .{},
        .order = .{},
    };
}

pub fn deinit(self: *Resources) void {
    // deinit resources in reverse insertion order
    while (self.order.popOrNull()) |type_id| {
        const entry = self.entries.get(type_id) orelse continue;
        entry.deinit(self.allocator);
    }

    self.entries.deinit(self.allocator);
    self.order.deinit(self.allocator);
}

pub fn contains(self: Resources, comptime T: type) bool {
    const type_id = TypeId.of(T);
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
    const type_id = TypeId.of(T);

    if (self.contains(T)) {
        std.log.warn("Resource already exists, {}", .{T});
        return;
    }

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
    try self.order.append(self.allocator, type_id);
}

pub fn get(self: Resources, comptime T: type) ?*T {
    const type_id = TypeId.of(T);
    const entry = self.entries.get(type_id) orelse return null;

    return @ptrCast(@alignCast(entry.data));
}
