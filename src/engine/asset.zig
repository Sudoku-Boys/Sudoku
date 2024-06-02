const std = @import("std");

const event = @import("event.zig");

const TypeId = @import("TypeId.zig");

fn decrementRefCount(ref_count: *u32) void {
    while (true) {
        // load the `ref_count` atomically
        const current_ref_count = @atomicLoad(u32, ref_count, .seq_cst);

        if (current_ref_count == 0) {
            std.log.warn("Reference count is already 0", .{});
            return;
        }

        // calculate the new `ref_count`
        const new_ref_count = current_ref_count - 1;

        // attempt to atomically swap the `ref_count` with the new value
        const res = @cmpxchgWeak(u32, ref_count, current_ref_count, new_ref_count, .seq_cst, .seq_cst);

        // if the swap was unsuccessful, retry
        if (res == null) break;
    }
}

fn incrementRefCount(ref_count: *u32) void {
    while (true) {
        // load the `ref_count` atomically
        const current_ref_count = @atomicLoad(u32, ref_count, .seq_cst);

        // calculate the new `ref_count`
        const new_ref_count = current_ref_count + 1;

        // attempt to atomically swap the `ref_count` with the new value
        const res = @cmpxchgWeak(u32, ref_count, current_ref_count, new_ref_count, .seq_cst, .seq_cst);

        // if the swap was unsuccessful, retry
        if (res == null) break;
    }
}

pub const DynamicAssetId = struct {
    const Self = @This();

    type_id: TypeId,
    index: usize,
    ref_count: *u32,

    pub fn deinit(self: Self) void {
        decrementRefCount(self.ref_count);
    }

    pub fn eql(a: Self, b: Self) bool {
        return a.type_id == b.type_id and a.index == b.index;
    }

    pub fn increment(self: Self) void {
        incrementRefCount(self.ref_count);
    }

    /// Try to cast the `DynamicAssetId` to an `AssetId`, with type `T`.
    ///
    /// Returns `null` if the type does not match.
    pub fn tryCast(self: Self, comptime T: type) ?AssetId(T) {
        if (self.type_id != std.meta.activeTag(@typeInfo(T))) return null;

        return self.cast();
    }

    /// Cast the `DynamicAssetId` to an `AssetId`, with type `T`.
    pub fn cast(self: Self, comptime T: type) AssetId(T) {
        return .{
            .index = self.index,
            .ref_count = self.ref_count,
        };
    }
};

pub fn AssetId(comptime T: type) type {
    return struct {
        const Self = @This();

        index: usize,
        ref_count: *u32,

        pub const Item = T;

        pub fn deinit(self: Self) void {
            decrementRefCount(self.ref_count);
        }

        pub fn eql(a: Self, b: Self) bool {
            return a.index == b.index;
        }

        pub fn increment(self: Self) void {
            incrementRefCount(self.ref_count);
        }

        pub fn dynamic(self: Self) DynamicAssetId {
            return .{
                .type_id = TypeId(T),
                .index = self.index,
                .ref_count = self.ref_count,
            };
        }

        pub fn cast(self: Self, comptime U: type) AssetId(U) {
            return .{
                .index = self.index,
                .ref_count = self.ref_count,
            };
        }
    };
}

pub fn AssetEvent(comptime T: type) type {
    return union(enum) {
        Added: AssetId(T),
        Modified: AssetId(T),
        Removed: AssetId(T),
    };
}

/// A collection of assets, indexed by `AssetId`.
pub fn Assets(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        entries: std.AutoHashMapUnmanaged(usize, Asset),
        events: std.ArrayListUnmanaged(AssetEvent(T)),
        next_index: usize,

        pub const Asset = struct {
            item: T,
            ref_count: *u32,

            pub fn refCount(self: Self) u32 {
                return @atomicLoad(u32, self.ref_count, .seq_cst);
            }

            pub fn setRefCount(self: Self, new_ref_count: u32) void {
                @atomicStore(u32, self.ref_count, new_ref_count, .seq_cst);
            }

            fn deinit(self: *Asset, allocator: std.mem.Allocator) void {
                if (comptime hasDeinit(T)) {
                    self.item.deinit();
                }

                allocator.destroy(self.ref_count);
            }
        };

        pub const Entry = struct {
            id: AssetId(T),
            asset: *Asset,

            pub fn item(self: Entry) T {
                return self.asset.item;
            }

            pub fn refCount(self: Entry) u32 {
                return self.asset.refCount();
            }

            pub fn setRefCount(self: Entry, new_ref_count: u32) void {
                self.asset.setRefCount(new_ref_count);
            }
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .entries = .{},
                .events = .{},
                .next_index = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            var entries = self.entries.valueIterator();
            while (entries.next()) |entry| {
                entry.deinit(self.allocator);
            }

            self.entries.deinit(self.allocator);
            self.events.deinit(self.allocator);
        }

        pub fn len(self: Self) usize {
            return self.entries.count();
        }

        pub fn contains(self: *Self, id: AssetId(T)) bool {
            return self.entries.contains(id.index);
        }

        /// Add an asset to the collection and return its `AssetId`.
        ///
        /// This id will have a reference count of 1, calling `deinit` on it will
        /// cause the asset to be remove next time `clean` is called.
        pub fn add(self: *Self, item: T) !AssetId(T) {
            const index = self.next_index;
            self.next_index += 1;

            const ref_count = try self.allocator.create(u32);
            ref_count.* = 1;

            const entry = Asset{
                .item = item,
                .ref_count = ref_count,
            };

            const id = AssetId(T){
                .index = index,
                .ref_count = ref_count,
            };

            try self.entries.put(self.allocator, index, entry);
            try self.events.append(self.allocator, AssetEvent(T){ .Added = id });

            return .{
                .index = index,
                .ref_count = ref_count,
            };
        }

        /// Set the value of an asset, returning the old value.
        ///
        /// If `id` is invalid returns `null`.
        pub fn put(self: *Self, id: AssetId(T), item: T) !AssetId(T) {
            if (self.contains(id)) {
                try self.remove(id);
            }

            const ref_count = try self.allocator.create(u32);
            ref_count.* = 1;

            const entry = Asset{
                .item = item,
                .ref_count = ref_count,
            };

            try self.entries.put(self.allocator, id.index, entry);
            try self.events.append(self.allocator, AssetEvent(T){ .Added = id });

            return .{
                .index = id.index,
                .ref_count = ref_count,
            };
        }

        pub fn remove(self: *Self, id: AssetId(T)) !void {
            if (self.getAsset(id)) |entry| {
                entry.deinit(self.allocator);
                _ = self.entries.remove(id.index);

                const e = AssetEvent(T){ .Removed = id };
                try self.events.append(self.allocator, e);
            }
        }

        /// Remove assets with a reference count of 0.
        pub fn clean(self: *Self) !void {
            var invalid = std.ArrayList(usize).init(self.allocator);

            var it = self.entries.iterator();
            while (it.next()) |entry| {
                const ref_count = @atomicLoad(u32, entry.value_ptr.ref_count, .seq_cst);
                if (ref_count > 0) continue;

                entry.value_ptr.deinit(self.allocator);

                try invalid.append(entry.key_ptr.*);

                std.log.info("Cleaned asset: 0x{x}", .{entry.key_ptr.*});
            }

            for (invalid.items) |index| {
                _ = self.entries.remove(index);
            }

            invalid.deinit();
        }

        /// Get the asset with the given `id`.
        pub fn sendEvents(
            self: *Self,
            writer: event.EventWriter(AssetEvent(T)),
        ) !void {
            for (self.events.items) |e| {
                try writer.send(e);
            }

            self.events.clearRetainingCapacity();
        }

        pub fn getAsset(self: Self, id: AssetId(T)) ?*Asset {
            return self.entries.getPtr(id.index);
        }

        pub fn get(self: Self, id: AssetId(T)) ?T {
            if (self.getAsset(id)) |entry| return entry.item;

            return null;
        }

        /// Get a pointer to the asset with the given `id`.
        pub fn getPtr(self: Self, id: AssetId(T)) ?*T {
            if (self.getAsset(id)) |entry| {
                const e = AssetEvent(T){ .Modified = id };
                try self.events.append(self.allocator, e);

                return &entry.item;
            }

            return null;
        }

        pub const Iterator = struct {
            it: std.AutoHashMapUnmanaged(usize, Asset).Iterator,

            pub fn next(self: *Iterator) ?Entry {
                if (self.it.next()) |entry| {
                    const id = .{
                        .index = entry.key_ptr.*,
                        .ref_count = entry.value_ptr.ref_count,
                    };

                    return .{
                        .id = id,
                        .asset = entry.value_ptr,
                    };
                }

                return null;
            }
        };

        pub const AssetIterator = struct {
            it: std.AutoHashMapUnmanaged(usize, Asset).Iterator,

            pub fn next(self: *AssetIterator) ?*T {
                if (self.it.next()) |entry| {
                    return &entry.value_ptr.asset;
                }

                return null;
            }
        };

        pub fn iterator(self: *Self) Iterator {
            return .{
                .it = self.entries.iterator(),
            };
        }

        pub fn assetIterator(self: *Self) AssetIterator {
            return .{
                .it = self.entries.iterator(),
            };
        }
    };
}

fn hasDeinit(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Struct, .Union, .Enum, .Opaque => {},
        else => return false,
    }

    if (!@hasDecl(T, "deinit")) return false;

    const deinit_decl = @field(T, "deinit");
    const DeinitType = @TypeOf(deinit_decl);

    if (@typeInfo(DeinitType) != .Fn) return false;

    const deinit_fn = @typeInfo(DeinitType).Fn;

    if (deinit_fn.params.len != 1) {
        @compileError("deinit function must take exactly one parameter");
    }

    if (deinit_fn.return_type != void) {
        @compileError("deinit function must return void");
    }

    return true;
}
