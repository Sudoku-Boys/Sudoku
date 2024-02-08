const std = @import("std");

const api = @cImport({
    @cInclude("vulkan/vulkan.h");
});

fn vkEnumIsValidField(comptime name: []const u8, comptime prefix: []const u8) bool {
    if (!std.mem.startsWith(u8, name, prefix)) return false;
    if (std.mem.startsWith(u8, name[prefix.len..], "FEATURE")) return false;
    if (std.mem.startsWith(u8, name[prefix.len..], "MAX_ENUM")) return false;

    return true;
}

fn vkEnumFieldName(comptime name: []const u8) []const u8 {
    comptime var output: [name.len]u8 = undefined;
    var len: usize = 0;

    var is_upper = true;

    for (name) |c| {
        if (c == '_') {
            is_upper = true;

            continue;
        }

        if (std.ascii.isAlphabetic(c)) {
            output[len] = if (is_upper) std.ascii.toUpper(c) else std.ascii.toLower(c);

            len += 1;
            is_upper = false;
        } else {
            output[len] = c;
            len += 1;

            is_upper = true;
        }
    }

    return output[0..len];
}

const VkEnumField = struct {
    name: []const u8,
    value: isize,
};

fn vkEnumFields(comptime fields: []VkEnumField, comptime prefix: []const u8) usize {
    const decls = @typeInfo(api).Struct.decls;

    var i = 0;
    outer: for (decls) |decl| {
        if (!vkEnumIsValidField(decl.name, prefix)) continue;
        const value = @field(api, decl.name);

        for (fields[0..i]) |field| {
            if (field.value == value) continue :outer;
        }

        var start = prefix.len;
        var end = decl.name.len;

        if (std.mem.endsWith(u8, decl.name[start..end], "_KHR")) {
            end -= 4;
        }

        if (std.mem.endsWith(u8, decl.name[start..end], "_EXT")) {
            end -= 4;
        }

        const field_name = vkEnumFieldName(decl.name[start..end]);

        fields[i] = VkEnumField{
            .name = field_name,
            .value = value,
        };

        i += 1;
    }

    return i;
}

fn vkEnum(
    writer: anytype,
    comptime tag: type,
    name: []const u8,
    comptime prefix: []const u8,
) !void {
    @setEvalBranchQuota(1 << 18);

    comptime var fields: [1024]VkEnumField = undefined;
    const count = comptime vkEnumFields(&fields, prefix);

    try writer.print("// Enum for {s}\n", .{prefix});
    try writer.print("pub const {s} = enum({s}) {{\n", .{ name, @typeName(tag) });

    for (fields[0..count]) |field| {
        try writer.print("    {s} = {},\n", .{ field.name, field.value });
    }

    try writer.print("}};\n\n", .{});
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    defer stdout.close();

    try vkEnum(stdout.writer(), u32, "AddressMode", "VK_SAMPLER_ADDRESS_MODE_");
    try vkEnum(stdout.writer(), u32, "BorderColor", "VK_BORDER_COLOR_");
    try vkEnum(stdout.writer(), u32, "BindingType", "VK_DESCRIPTOR_TYPE_");
    try vkEnum(stdout.writer(), u32, "BlendFactor", "VK_BLEND_FACTOR_");
    try vkEnum(stdout.writer(), u32, "BlendOp", "VK_BLEND_OP_");
    try vkEnum(stdout.writer(), u32, "CompareOp", "VK_COMPARE_OP_");
    try vkEnum(stdout.writer(), u32, "VertexInputRate", "VK_VERTEX_INPUT_RATE_");
    try vkEnum(stdout.writer(), u32, "Filter", "VK_FILTER_");
    try vkEnum(stdout.writer(), u32, "FrontFace", "VK_FRONT_FACE_");
    try vkEnum(stdout.writer(), u32, "LoadOp", "VK_ATTACHMENT_LOAD_OP_");
    try vkEnum(stdout.writer(), u32, "LogicOp", "VK_LOGIC_OP_");
    try vkEnum(stdout.writer(), u32, "ImageFormat", "VK_FORMAT_");
    try vkEnum(stdout.writer(), u32, "ImageTiling", "VK_IMAGE_TILING_");
    try vkEnum(stdout.writer(), u32, "ImageLayout", "VK_IMAGE_LAYOUT_");
    try vkEnum(stdout.writer(), u32, "MipmapMode", "VK_SAMPLER_MIPMAP_MODE_");
    try vkEnum(stdout.writer(), u32, "SharingMode", "VK_SHARING_MODE_");
    try vkEnum(stdout.writer(), u32, "PresentMode", "VK_PRESENT_MODE_");
    try vkEnum(stdout.writer(), u32, "PrimitiveTopology", "VK_PRIMITIVE_TOPOLOGY_");
    try vkEnum(stdout.writer(), u32, "PolygonMode", "VK_POLYGON_MODE_");
    try vkEnum(stdout.writer(), u32, "StencilOp", "VK_STENCIL_OP_");
    try vkEnum(stdout.writer(), u32, "StoreOp", "VK_ATTACHMENT_STORE_OP_");
}
