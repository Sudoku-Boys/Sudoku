const std = @import("std");

const math = @import("../math.zig");

const Mesh = @This();

pub fn Vertices(comptime T: type) type {
    if (@sizeOf(T) == 0) {
        @compileError("Vertex type must have a non-zero size");
    }

    if (@alignOf(T) > 16) {
        @compileError("Vertex type must be 16-byte aligned or less");
    }

    return struct {
        const Self = @This();

        data: std.ArrayListAligned(u8, 16),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .data = std.ArrayListAligned(u8, 16).init(allocator),
            };
        }

        pub fn deinit(self: Self) void {
            self.data.deinit();
        }

        pub fn cast(self: *Self, comptime U: type) *Vertices(U) {
            return @ptrCast(self);
        }

        pub fn len(self: Self) usize {
            return self.data.items.len / @sizeOf(T);
        }

        pub fn append(self: *Self, vertex: T) !void {
            std.debug.assert(self.data.items.len % @sizeOf(T) == 0);

            const bytes = std.mem.toBytes(vertex);
            try self.data.appendSlice(&bytes);
        }

        pub fn appendSlice(self: *Self, vertices: []const T) !void {
            std.debug.assert(self.data.items.len % @sizeOf(T) == 0);

            const bytes = std.mem.sliceAsBytes(vertices);
            try self.data.appendSlice(&bytes);
        }

        pub fn appendNTimes(self: *Self, vertex: T, n: usize) !void {
            for (0..n) |_| {
                try self.append(vertex);
            }
        }

        pub fn getPtr(self: Self, index: usize) *T {
            const i = index * @sizeOf(T);
            return @ptrCast(@alignCast(&self.data.items[i]));
        }

        pub fn get(self: Self, index: usize) T {
            return self.getPtr(index).?;
        }
    };
}

pub const Attribute = struct {
    name: []const u8,
    vertices: Vertices(u8),
};

pub const POSITION = "position";
pub const NORMAL = "normal";
pub const TEX_COORD_0 = "tex_coord_0";
pub const COLOR = "color";

attributes: std.ArrayList(Attribute),
indices: std.ArrayList(u32),

pub fn init(allocator: std.mem.Allocator) Mesh {
    const attributes = std.ArrayList(Attribute).init(allocator);
    const indices = std.ArrayList(u32).init(allocator);

    return .{
        .attributes = attributes,
        .indices = indices,
    };
}

pub fn deinit(self: Mesh) void {
    for (self.attributes.items) |attribute| {
        attribute.vertices.deinit();
    }

    self.attributes.deinit();
    self.indices.deinit();
}

pub fn containsAttribute(self: Mesh, name: []const u8) bool {
    for (self.attributes.items) |attribute| {
        if (std.mem.eql(u8, attribute.name, name)) return true;
    }

    return false;
}

pub fn getAttributePtr(self: Mesh, comptime T: type, name: []const u8) ?*Vertices(T) {
    for (self.attributes.items) |*attribute| {
        if (std.mem.eql(u8, attribute.name, name)) {
            return attribute.vertices.cast(T);
        }
    }

    return null;
}

pub fn getAttribute(self: Mesh, comptime T: type, name: []const u8) ?Vertices(T) {
    return (self.getAttributePtr(T, name) orelse return null).*;
}

pub fn addAttribute(self: *Mesh, comptime T: type, name: []const u8) !*Vertices(T) {
    if (self.getAttributePtr(T, name)) |attribute| return attribute;

    const vertices = Vertices(u8).init(self.attributes.allocator);

    const index = self.attributes.items.len;
    try self.attributes.append(.{
        .name = name,
        .vertices = vertices,
    });

    return self.attributes.items[index].vertices.cast(T);
}

pub fn vertexBytes(self: Mesh, name: []const u8) ?[]const u8 {
    for (self.attributes.items) |attribute| {
        if (std.mem.eql(u8, attribute.name, name)) {
            return attribute.vertices.data.items;
        }
    }

    return null;
}

pub fn indexBytes(mesh: Mesh) []const u8 {
    return std.mem.sliceAsBytes(mesh.indices.items);
}

pub fn plane(allocator: std.mem.Allocator, size: anytype, color: u32) !Mesh {
    var mesh = init(allocator);

    const s = math.Vec2.all(size);

    const positions = try mesh.addAttribute([3]f32, POSITION);
    try positions.append(math.vec3(-s._.x, 0.0, -s._.y).f);
    try positions.append(math.vec3(-s._.x, 0.0, s._.y).f);
    try positions.append(math.vec3(s._.x, 0.0, -s._.y).f);
    try positions.append(math.vec3(s._.x, 0.0, s._.y).f);

    const normals = try mesh.addAttribute([3]f32, NORMAL);
    try normals.appendNTimes(math.Vec3.Y.f, 4);

    const tex_coords = try mesh.addAttribute(math.Vec2, TEX_COORD_0);
    try tex_coords.append(math.vec2(0.0, 0.0));
    try tex_coords.append(math.vec2(0.0, 1.0));
    try tex_coords.append(math.vec2(1.0, 0.0));
    try tex_coords.append(math.vec2(1.0, 1.0));

    const colors = try mesh.addAttribute(u32, COLOR);
    try colors.appendNTimes(color, 4);

    try mesh.indices.appendSlice(&.{ 0, 1, 2, 2, 1, 3 });

    return mesh;
}

pub fn cube(allocator: std.mem.Allocator, size: f32, color: u32) !Mesh {
    var mesh = init(allocator);

    const s = math.Vec3.all(size);

    const positions = try mesh.addAttribute([3]f32, POSITION);

    // front
    try positions.append(math.vec3(-s._.x, -s._.y, s._.z).f);
    try positions.append(math.vec3(s._.x, -s._.y, s._.z).f);
    try positions.append(math.vec3(s._.x, s._.y, s._.z).f);
    try positions.append(math.vec3(-s._.x, s._.y, s._.z).f);

    // back
    try positions.append(math.vec3(-s._.x, -s._.y, -s._.z).f);
    try positions.append(math.vec3(s._.x, -s._.y, -s._.z).f);
    try positions.append(math.vec3(s._.x, s._.y, -s._.z).f);
    try positions.append(math.vec3(-s._.x, s._.y, -s._.z).f);

    // top
    try positions.append(math.vec3(-s._.x, s._.y, s._.z).f);
    try positions.append(math.vec3(s._.x, s._.y, s._.z).f);
    try positions.append(math.vec3(s._.x, s._.y, -s._.z).f);
    try positions.append(math.vec3(-s._.x, s._.y, -s._.z).f);

    // bottom
    try positions.append(math.vec3(-s._.x, -s._.y, s._.z).f);
    try positions.append(math.vec3(s._.x, -s._.y, s._.z).f);
    try positions.append(math.vec3(s._.x, -s._.y, -s._.z).f);
    try positions.append(math.vec3(-s._.x, -s._.y, -s._.z).f);

    // right
    try positions.append(math.vec3(s._.x, -s._.y, s._.z).f);
    try positions.append(math.vec3(s._.x, -s._.y, -s._.z).f);
    try positions.append(math.vec3(s._.x, s._.y, -s._.z).f);
    try positions.append(math.vec3(s._.x, s._.y, s._.z).f);

    // left
    try positions.append(math.vec3(-s._.x, -s._.y, s._.z).f);
    try positions.append(math.vec3(-s._.x, -s._.y, -s._.z).f);
    try positions.append(math.vec3(-s._.x, s._.y, -s._.z).f);
    try positions.append(math.vec3(-s._.x, s._.y, s._.z).f);

    const normals = try mesh.addAttribute([3]f32, NORMAL);
    try normals.appendNTimes(math.Vec3.Z.f, 4);
    try normals.appendNTimes(math.Vec3.NEG_Z.f, 4);
    try normals.appendNTimes(math.Vec3.Y.f, 4);
    try normals.appendNTimes(math.Vec3.NEG_Y.f, 4);
    try normals.appendNTimes(math.Vec3.X.f, 4);
    try normals.appendNTimes(math.Vec3.NEG_X.f, 4);

    const tex_coords = try mesh.addAttribute(math.Vec2, TEX_COORD_0);
    for (0..6) |_| {
        try tex_coords.append(math.vec2(0.0, 0.0));
        try tex_coords.append(math.vec2(1.0, 0.0));
        try tex_coords.append(math.vec2(1.0, 1.0));
        try tex_coords.append(math.vec2(0.0, 1.0));
    }

    const colors = try mesh.addAttribute(u32, COLOR);
    try colors.appendNTimes(color, 24);

    try mesh.indices.appendSlice(&.{
        0,  1,  2,  2,  3,  0,
        4,  6,  5,  7,  6,  4,
        8,  9,  10, 10, 11, 8,
        12, 14, 13, 15, 14, 12,
        16, 17, 18, 18, 19, 16,
        20, 22, 21, 23, 22, 20,
    });

    return mesh;
}
