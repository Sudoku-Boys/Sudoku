const std = @import("std");

const TypeId = @import("TypeId.zig");

fn decrementRefCount(ref_count: *u32) void {
    while (true) {
        // load the `ref_count` atomically
        const current_ref_count = @atomicLoad(u32, ref_count, .seq_cst);
        std.debug.assert(current_ref_count > 0);

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

/// A collection of assets, indexed by `AssetId`.
pub fn Assets(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        entries: std.AutoHashMapUnmanaged(usize, Asset),
        next_index: usize,

        pub const Asset = struct {
            item: T,
            version: u32,
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

            pub fn version(self: Entry) u32 {
                return self.asset.version;
            }

            pub fn setRefCount(self: Entry, new_ref_count: u32) void {
                self.asset.setRefCount(new_ref_count);
            }

            pub fn setVersion(self: Entry, new_version: u32) void {
                self.asset.version = new_version;
            }
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .entries = .{},
                .next_index = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            var entries = self.entries.valueIterator();
            while (entries.next()) |entry| {
                entry.deinit(self.allocator);
            }

            self.entries.deinit(self.allocator);
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
                .version = 0,
                .ref_count = ref_count,
            };

            try self.entries.put(self.allocator, index, entry);

            return .{
                .index = index,
                .ref_count = ref_count,
            };
        }

        /// Set the value of an asset, returning the old value.
        ///
        /// If `id` is invalid returns `null`.
        pub fn put(self: *Self, id: AssetId(T), item: T) !AssetId(T) {
            var new_version: u32 = 0;

            if (self.contains(id)) {
                new_version = self.version(id);
                self.remove(id);
            }

            const ref_count = try self.allocator.create(u32);
            ref_count.* = 1;

            const entry = Asset{
                .item = item,
                .version = new_version,
                .ref_count = ref_count,
            };

            try self.entries.put(self.allocator, id.index, entry);

            return .{
                .index = id.index,
                .ref_count = ref_count,
            };
        }

        pub fn remove(self: *Self, id: AssetId(T)) void {
            if (self.getAsset(id)) |entry| {
                entry.deinit(self.allocator);
                _ = self.entries.remove(id.index);
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

        pub fn getAsset(self: Self, id: AssetId(T)) ?*Asset {
            return self.entries.getPtr(id.index);
        }

        pub fn get(self: Self, id: AssetId(T)) ?T {
            if (self.getAsset(id)) |entry| return entry.item;

            return null;
        }

        /// Get a pointer to the asset with the given `id`.
        ///
        /// This will increment the version of the asset.
        pub fn getPtr(self: Self, id: AssetId(T)) ?*T {
            if (self.getAsset(id)) |entry| {
                entry.version += 1;
                return &entry.item;
            }

            return null;
        }

        /// Get the version of the asset with the given `id`.
        pub fn getVersion(self: Self, id: AssetId(T)) ?u32 {
            const entry = self.getAsset(id) orelse return null;
            return entry.version;
        }

        /// Get the version of the asset with the given `id`.
        ///
        /// # Safety
        /// - `id` must be contained in the collection.
        pub fn version(self: *Self, id: AssetId(T)) u32 {
            return self.getVersion(id).?;
        }

        /// Set the version of the asset with the given `id`.
        pub fn setVersion(self: *Self, id: AssetId(T), new_version: u32) void {
            if (self.getAsset(id)) |entry| {
                entry.version = new_version;
            }
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
