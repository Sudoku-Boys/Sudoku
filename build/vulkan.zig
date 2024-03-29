const std = @import("std");

fn generateVulkanEnums(b: *std.Build) !std.Build.LazyPath {
    const tool = b.addExecutable(.{
        .name = "generate_vulkan_enums",
        .root_source_file = .{ .path = "build/vulkan/generate_enums.zig" },
    });

    if (b.host.target.os.tag == .windows) {
        addIncludePath(tool);
        tool.addLibraryPath(.{ .path = "ext/win/lib" });
    }

    tool.linkSystemLibrary("vulkan");
    tool.linkLibC();

    const tool_step = b.addRunArtifact(tool);
    return tool_step.captureStdOut();
}

fn generateVulkanFlags(b: *std.Build) !std.Build.LazyPath {
    const tool = b.addExecutable(.{
        .name = "generate_vulkan_flags",
        .root_source_file = .{ .path = "build/vulkan/generate_flags.zig" },
    });

    if (b.host.target.os.tag == .windows) {
        addIncludePath(tool);
        tool.addLibraryPath(.{ .path = "ext/win/lib" });
    }

    tool.linkSystemLibrary("vulkan");
    tool.linkLibC();

    const tool_step = b.addRunArtifact(tool);
    return tool_step.captureStdOut();
}

pub fn createVulkanModule(b: *std.Build) !*std.Build.Module {
    const vulkan_enums = try generateVulkanEnums(b);
    const vulkan_flags = try generateVulkanFlags(b);

    const vulkan = b.createModule(.{
        .source_file = .{ .path = "vulkan/vk.zig" },
    });

    const write = vulkan.builder.addWriteFiles();
    write.addCopyFileToSource(vulkan_enums, "vulkan/generated/enums.zig");
    write.addCopyFileToSource(vulkan_flags, "vulkan/generated/flags.zig");

    b.step("generate-vulkan-types", "Generate Vulkan bindings").dependOn(&write.step);

    return vulkan;
}

pub fn addIncludePath(s: *std.Build.Step.Compile) void {
    s.addIncludePath(.{ .path = "ext/Vulkan-Headers/include" });
}
