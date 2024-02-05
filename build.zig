const std = @import("std");

/// Use glslc to compile a shader file to SPIR-V
fn compileShader(b: *std.Build, steps: []const *std.Build.Step.Compile, path: []const u8) void {
    var glsl_run: *std.Build.Step.Run = undefined;
    if (b.host.target.os.tag == .windows) {
        glsl_run = b.addSystemCommand(&.{"bin/win/glslc"});
    } else if (b.host.target.os.tag == .linux) {
        glsl_run = b.addSystemCommand(&.{"glslc"});
    }

    glsl_run.addFileArg(.{ .path = path });
    glsl_run.addArgs(&.{ "-o", "-" });

    const output = glsl_run.captureStdOut();

    const file = b.addInstallFile(output, path);
    b.getInstallStep().dependOn(&file.step);

    for (steps) |step| {
        step.addAnonymousModule(path, .{
            .source_file = output,
        });
    }
}

fn isShaderFile(name: []const u8) bool {
    const ext = std.fs.path.extension(name);

    const is_vert = std.mem.eql(u8, ext, ".vert");
    const is_frag = std.mem.eql(u8, ext, ".frag");

    return is_vert or is_frag;
}

fn compileShaders(b: *std.Build, steps: []const *std.Build.Step.Compile) !void {
    const dir = std.fs.cwd();
    const shader = try dir.openIterableDir("shader", .{});

    var it = shader.iterate();
    while (try it.next()) |entry| {
        if (isShaderFile(entry.name)) {
            const path = try std.mem.join(b.allocator, "/", &.{ "shader", entry.name });
            compileShader(b, steps, path);
        }
    }
}

fn generateVulkanEnums(b: *std.Build) !std.Build.LazyPath {
    const tool = b.addExecutable(.{
        .name = "generate_vulkan_enums",
        .root_source_file = .{ .path = "build/vulkan/generate_enums.zig" },
    });

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

    tool.linkSystemLibrary("vulkan");
    tool.linkLibC();

    const tool_step = b.addRunArtifact(tool);
    return tool_step.captureStdOut();
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_enums = try generateVulkanEnums(b);
    const vulkan_flags = try generateVulkanFlags(b);

    const f = b.addInstallFile(vulkan_flags, "vulkan_flags.zig");
    b.getInstallStep().dependOn(&f.step);

    const exe = b.addExecutable(.{
        .name = "Sudoku",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (b.host.target.os.tag == .windows) {
        exe.addIncludePath(.{ .path = "include/win" });
        exe.addLibraryPath(.{ .path = "lib/win" });
        exe.linkSystemLibrary("glfw3dll");
        exe.linkSystemLibrary("vulkan-1");
    } else if (b.host.target.os.tag == .linux) {
        exe.addIncludePath(.{ .path = "include/linux" });
        exe.addLibraryPath(.{ .path = "lib/linux" });
        exe.linkSystemLibrary("glfw");
        exe.linkSystemLibrary("vulkan");
    } else {
        std.debug.panic("Unsupported OS\n", .{});
    }

    exe.addAnonymousModule("vulkan_enums", .{ .source_file = vulkan_enums });
    exe.addAnonymousModule("vulkan_flags", .{ .source_file = vulkan_flags });

    exe.linkLibC();

    try compileShaders(b, &.{exe});

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.host.target.os.tag == .windows) {
        run_cmd.addPathDir("lib/win");
    } else if (b.host.target.os.tag == .linux) {
        run_cmd.addPathDir("lib/linux");
    } else {
        std.debug.panic("Unsupported OS\n", .{});
    }

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
