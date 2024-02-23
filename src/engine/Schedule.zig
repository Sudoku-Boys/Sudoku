const std = @import("std");

const System = @import("System.zig");

const Schedule = @This();

const SystemLabel = struct {
    type_id: std.builtin.TypeId,
    hash: u64,

    pub fn of(label: anytype) SystemLabel {
        const T = @TypeOf(label);
        const type_id = std.meta.activeTag(@typeInfo(T));

        var hasher = std.hash.XxHash64.init(42069);
        std.hash.autoHash(&hasher, label);

        return SystemLabel{
            .type_id = type_id,
            .hash = hasher.final(),
        };
    }
};

const Entry = struct {
    system: System,
    labels: std.ArrayListUnmanaged(SystemLabel),
    before: std.ArrayListUnmanaged(SystemLabel),
    after: std.ArrayListUnmanaged(SystemLabel),
};

allocator: std.mem.Allocator,
entries: std.ArrayListUnmanaged(Entry),
order: ?std.ArrayListUnmanaged(usize),

pub fn init(allocator: std.mem.Allocator) Schedule {
    return .{
        .allocator = allocator,
        .entries = .{},
        .order = null,
    };
}

pub fn deinit(self: *Schedule) void {
    self.entries.deinit(self.allocator);

    if (self.order) |*order| order.deinit(self.allocator);
}

pub const AddedSystem = struct {
    allocator: std.mem.Allocator,
    entry: *Entry,

    pub fn label(self: AddedSystem, l: anytype) !void {
        try self.entry.labels.append(self.allocator, SystemLabel.of(l));
    }

    pub fn before(self: AddedSystem, l: anytype) !void {
        try self.entry.before.append(self.allocator, SystemLabel.of(l));
    }

    pub fn after(self: AddedSystem, l: anytype) !void {
        try self.entry.after.append(self.allocator, SystemLabel.of(l));
    }
};

pub fn addSystem(self: *Schedule, system: anytype) !AddedSystem {
    const index = self.entries.items.len;
    const sys = try System.init(self.allocator, system);

    try self.entries.append(self.allocator, .{
        .system = sys,
        .labels = .{},
        .before = .{},
        .after = .{},
    });

    return .{
        .allocator = self.allocator,
        .entry = &self.entries.items[index],
    };
}
