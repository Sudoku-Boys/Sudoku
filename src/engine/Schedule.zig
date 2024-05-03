const std = @import("std");

const System = @import("system2.zig");
const World = @import("World.zig");
const TypeId = @import("TypeId.zig");

const Schedule = @This();

const SystemLabel = struct {
    type_id: TypeId,
    hash: u64,

    pub fn of(label: anytype) SystemLabel {
        const T = @TypeOf(label);
        const type_id = TypeId.of(T);

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

    pub fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        self.system.deinit(allocator);
        self.labels.deinit(allocator);
        self.before.deinit(allocator);
        self.after.deinit(allocator);
    }
};

pub const Error = error{
    CircularDependency,
};

allocator: std.mem.Allocator,
entries: std.ArrayListUnmanaged(Entry),
order: ?[]usize,

pub fn init(allocator: std.mem.Allocator) Schedule {
    return .{
        .allocator = allocator,
        .entries = .{},
        .order = null,
    };
}

pub fn deinit(self: *Schedule) void {
    for (self.entries.items) |*entry| entry.deinit(self.allocator);

    self.entries.deinit(self.allocator);

    if (self.order) |order| self.allocator.free(order);
}

pub fn invalidate(self: *Schedule) void {
    if (self.order) |order| self.allocator.free(order);
    self.order = null;
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

    self.invalidate();

    return .{
        .allocator = self.allocator,
        .entry = &self.entries.items[index],
    };
}

// shorthands for ease of use
const LabelToIndex = std.AutoHashMapUnmanaged(SystemLabel, std.ArrayListUnmanaged(usize));
const Dependencies = std.AutoHashMapUnmanaged(usize, std.ArrayListUnmanaged(usize));

pub fn sort(self: *Schedule) ![]usize {
    // a map from label to indices, note that there can be multiple indices for the same label
    var labelToIndex: LabelToIndex = .{};
    defer {
        var it = labelToIndex.valueIterator();
        while (it.next()) |v| v.deinit(self.allocator);

        labelToIndex.deinit(self.allocator);
    }

    for (self.entries.items, 0..) |entry, i| {
        for (entry.labels.items) |label| {
            if (!labelToIndex.contains(label)) {
                try labelToIndex.put(self.allocator, label, .{});
            }

            try labelToIndex.getPtr(label).?.append(self.allocator, i);
        }
    }

    // a map from index to the indices of systems that must run before it
    var dependencies: Dependencies = .{};
    defer {
        var it = dependencies.valueIterator();
        while (it.next()) |v| v.deinit(self.allocator);

        dependencies.deinit(self.allocator);
    }

    for (0..self.entries.items.len) |i| {
        if (!dependencies.contains(i)) {
            try dependencies.put(self.allocator, i, .{});
        }
    }

    for (self.entries.items, 0..) |entry, i| {
        // for each label this system should run after
        //  - append the indices of systems that have this label to
        //    the dependencies of this system
        for (entry.after.items) |after| {
            const indices = dependencies.getPtr(i).?;

            if (labelToIndex.get(after)) |indices_after| {
                try indices.appendSlice(self.allocator, indices_after.items);
            }
        }

        // for each label this system should run before do what we did for after
        // but in reverse
        for (entry.before.items) |before| {
            if (labelToIndex.get(before)) |indices_before| {
                for (indices_before.items) |index_before| {
                    const indices = dependencies.getPtr(index_before).?;

                    try indices.append(self.allocator, i);
                }
            }
        }
    }

    var order: std.ArrayListUnmanaged(usize) = .{};
    errdefer order.deinit(self.allocator);

    var visited: std.ArrayListUnmanaged(bool) = .{};
    defer visited.deinit(self.allocator);

    try visited.appendNTimes(self.allocator, false, self.entries.items.len);

    while (nextConsidered(&dependencies)) |i| {
        const next = try self.sortRecursive(&dependencies, &visited, i);
        try order.append(self.allocator, next);

        if (dependencies.getPtr(next)) |indices| {
            indices.deinit(self.allocator);
        }

        _ = dependencies.remove(next);
    }

    return order.toOwnedSlice(self.allocator);
}

fn nextConsidered(
    dependencies: *std.AutoHashMapUnmanaged(usize, std.ArrayListUnmanaged(usize)),
) ?usize {
    var it = dependencies.keyIterator();
    const next = it.next() orelse return null;
    return next.*;
}

fn sortRecursive(
    self: *Schedule,
    dependencies: *std.AutoHashMapUnmanaged(usize, std.ArrayListUnmanaged(usize)),
    visited: *std.ArrayListUnmanaged(bool),
    considered: usize,
) !usize {
    for (dependencies.get(considered).?.items) |dependency| {
        if (!dependencies.contains(dependency)) continue;

        if (visited.items[dependency]) {
            std.log.err("Circular dependency detected", .{});
            std.log.err(" - {any}", .{visited.items});

            return error.CircularDependency;
        }

        visited.items[considered] = true;

        const result = try self.sortRecursive(
            dependencies,
            visited,
            dependency,
        );

        visited.items[considered] = false;

        return result;
    }

    return considered;
}

pub fn run(self: *Schedule, world: *World) !void {
    // ensure the order is up to date
    if (self.order == null) {
        self.order = try self.sort();
    }

    // run the systems in order
    for (self.order.?) |index| {
        const entry = self.entries.items[index];
        try entry.system.run(world);
        try entry.system.apply(world);
    }
}
