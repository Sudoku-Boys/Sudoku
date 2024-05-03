const std = @import("std");

fn generateVulkanEnums(b: *std.Build) !std.Build.LazyPath {
    const tool = b.addExecutable(.{
        .target = b.host,
        .name = "generate_vulkan_enums",
        .root_source_file = .{ .path = "build/vulkan/generate_enums.zig" },
    });

    if (b.host.result.os.tag == .windows) {
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
        .target = b.host,
        .name = "generate_vulkan_flags",
        .root_source_file = .{ .path = "build/vulkan/generate_flags.zig" },
    });

    if (b.host.result.os.tag == .windows) {
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

    const vm = b.addModule("vulkan", .{
        .root_source_file = .{ .path = "vulkan/vk.zig" },
    });

    if (b.host.result.os.tag == .windows) {
        vm.addIncludePath(.{ .path = "ext/Vulkan-Headers/include" });
    }

    const write = b.addWriteFiles();
    write.addCopyFileToSource(vulkan_enums, "vulkan/generated/enums.zig");
    write.addCopyFileToSource(vulkan_flags, "vulkan/generated/flags.zig");

    const step = b.step("generate-vulkan-types", "Generate Vulkan bindings");
    step.dependOn(&write.step);

    return vm;
}

pub fn addIncludePath(s: *std.Build.Step.Compile) void {
    s.root_module.addIncludePath(.{ .path = "ext/Vulkan-Headers/include" });
}
