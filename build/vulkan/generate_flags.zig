const std = @import("std");

const api = @cImport({
    @cInclude("vulkan/vulkan.h");
});

fn vkFlagsIsValidField(comptime name: []const u8, comptime prefix: []const u8) bool {
    if (!std.mem.startsWith(u8, name, prefix)) return false;
    if (std.mem.startsWith(u8, name[prefix.len..], "FEATURE")) return false;
    if (!std.mem.endsWith(u8, name, "BIT")) return false;

    return true;
}

fn vkFlagFieldName(comptime name: []const u8) []const u8 {
    comptime var output: [name.len]u8 = undefined;

    for (name, 0..) |c, i| {
        if (std.ascii.isAlphabetic(c)) {
            output[i] = std.ascii.toLower(c);
        } else {
            output[i] = c;
        }
    }

    return &output;
}

const VkFlagsField = struct {
    name: []const u8,
};

fn vkFlagsFields(comptime fields: []?VkFlagsField, comptime prefix: []const u8) usize {
    const decls = @typeInfo(api).Struct.decls;

    var count = 0;
    for (decls) |decl| {
        // if the name is invalid, skip it
        if (!vkFlagsIsValidField(decl.name, prefix)) continue;

        var start = prefix.len;
        const end = decl.name.len - 4;

        // if the field has 2_ in the name, skip it
        if (std.mem.startsWith(u8, decl.name[start..], "2_")) continue;

        // calculate the index of the field
        const value = @field(api, decl.name);
        const index = std.math.log2_int(u64, value);

        // if the value is not a power of 2, skip it
        if (try std.math.powi(u64, 2, index) != value) continue;

        // if the index is out of bounds, panic
        if (index >= fields.len) {
            @compileError(std.fmt.comptimePrint("too many fields for prefix '{}', {}", .{ prefix, index }));
        }

        // if the field is already set, skip it
        if (fields[index] != null) continue;

        const stripped_name = decl.name[start..end];
        var field_name = vkFlagFieldName(stripped_name);

        fields[index] = .{
            .name = field_name,
        };

        count = @max(count, index + 1);
    }

    return count;
}

fn vkFlags(
    writer: anytype,
    comptime tag: type,
    name: []const u8,
    comptime prefix: []const u8,
) !void {
    @setEvalBranchQuota(1 << 18);

    comptime var fields: [@bitSizeOf(tag)]?VkFlagsField = .{null} ** @bitSizeOf(tag);
    const count = comptime vkFlagsFields(&fields, prefix);

    try writer.print("// Bitmask for {s}\n", .{prefix});
    try writer.print("pub const {s} = packed struct({s}) {{\n", .{ name, @typeName(tag) });

    for (fields[0..count], 0..) |field, i| {
        if (field) |f| {
            try writer.print("    {s}: bool = false,\n", .{f.name});
        } else {
            try writer.print("    _{}: bool = false,\n", .{i});
        }
    }

    if (count > @bitSizeOf(tag)) {
        std.debug.panic("too many fields in {s}", .{name});
    }

    const remaining = @bitSizeOf(tag) - count;

    if (remaining > 0) {
        try writer.print("    _unused: u{} = 0,\n", .{remaining});
    }

    try writer.print("\n", .{});

    try writer.print("    pub const ALL: {s} = .{{\n", .{name});

    for (fields[0..count]) |field| {
        if (field) |f| {
            try writer.print("        .{s} = true,\n", .{f.name});
        }
    }

    try writer.print("    }};\n", .{});

    try writer.print("}};\n\n", .{});
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    defer stdout.close();

    try vkFlags(stdout.writer(), u32, "Access", "VK_ACCESS_");
    try vkFlags(stdout.writer(), u32, "BufferUsages", "VK_BUFFER_USAGE_");
    try vkFlags(stdout.writer(), u32, "CullModes", "VK_CULL_MODE_");
    try vkFlags(stdout.writer(), u32, "ColorComponents", "VK_COLOR_COMPONENT_");
    try vkFlags(stdout.writer(), u32, "Dependencies", "VK_DEPENDENCY_");
    try vkFlags(stdout.writer(), u32, "ImageAspects", "VK_IMAGE_ASPECT_");
    try vkFlags(stdout.writer(), u32, "ImageUsages", "VK_IMAGE_USAGE_");
    try vkFlags(stdout.writer(), u32, "MemoryProperties", "VK_MEMORY_PROPERTY_");
    try vkFlags(stdout.writer(), u32, "PipelineStages", "VK_PIPELINE_STAGE_");
    try vkFlags(stdout.writer(), u32, "ShaderStages", "VK_SHADER_STAGE_");
}
