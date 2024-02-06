const std = @import("std");

const ShaderStage = enum {
    Vertex,
    Fragment,

    fn fromPath(name: []const u8) ?ShaderStage {
        const ext = std.fs.path.extension(name);

        if (std.mem.eql(u8, ext, ".vert")) return .Vertex;
        if (std.mem.eql(u8, ext, ".frag")) return .Fragment;

        return null;
    }

    fn argName(self: ShaderStage) []const u8 {
        switch (self) {
            .Vertex => return "vertex",
            .Fragment => return "fragment",
        }
    }
};

const CompiledShader = struct {
    name: []const u8,
    stage: ShaderStage,
    data: std.build.LazyPath,
};

fn compileShaderTool(
    b: *std.Build,
) *std.Build.Step.Compile {
    const tool = b.addExecutable(.{
        .name = "compile_shader",
        .root_source_file = .{ .path = "build/vulkan/compile_shader.zig" },
    });

    if (b.host.target.os.tag == .windows) {
        tool.addIncludePath(.{ .path = "include/win" });
        tool.addLibraryPath(.{ .path = "lib/win" });
        tool.linkSystemLibrary("shaderc_shared");
    } else {
        tool.linkSystemLibrary("shaderc_shared");
    }

    tool.linkLibC();

    return tool;
}

fn compileShader(
    b: *std.Build,
    tool: *std.Build.Step.Compile,
    path: []const u8,
    stage: ShaderStage,
) std.Build.LazyPath {
    const tool_step = b.addRunArtifact(tool);
    tool_step.addFileArg(.{ .path = path });
    tool_step.addArg(stage.argName());

    if (b.host.target.os.tag == .windows) {
        tool_step.addPathDir("lib/win");
    }

    return tool_step.captureStdOut();
}

fn compileShaders(
    b: *std.Build,
) !std.ArrayList(CompiledShader) {
    const tool = compileShaderTool(b);

    const dir = std.fs.cwd();
    var shader = try dir.openIterableDir("shader", .{});
    defer shader.close();

    var shaders = std.ArrayList(CompiledShader).init(b.allocator);

    var it = shader.iterate();
    while (try it.next()) |entry| {
        if (ShaderStage.fromPath(entry.name)) |stage| {
            const path = try std.mem.join(b.allocator, "/", &.{ "shader", entry.name });
            const data = compileShader(b, tool, path, stage);

            try shaders.append(CompiledShader{
                .name = path,
                .stage = stage,
                .data = data,
            });
        }
    }

    return shaders;
}

fn generateVulkanEnums(b: *std.Build) !std.Build.LazyPath {
    const tool = b.addExecutable(.{
        .name = "generate_vulkan_enums",
        .root_source_file = .{ .path = "build/vulkan/generate_enums.zig" },
    });

    if (b.host.target.os.tag == .windows) {
        tool.addIncludePath(.{ .path = "include/win" });
        tool.addLibraryPath(.{ .path = "lib/win" });
        tool.linkSystemLibrary("vulkan-1");
    } else {
        tool.linkSystemLibrary("vulkan");
    }

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
        tool.addIncludePath(.{ .path = "include/win" });
        tool.addLibraryPath(.{ .path = "lib/win" });
        tool.linkSystemLibrary("vulkan-1");
    } else {
        tool.linkSystemLibrary("vulkan");
    }

    tool.linkLibC();

    const tool_step = b.addRunArtifact(tool);
    return tool_step.captureStdOut();
}

fn createVulkanModule(b: *std.Build) !*std.Build.Module {
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

fn addSudokuBackendTests(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) void {
    const exe = b.addExecutable(.{
        .name = "sudoku-backend",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/sudoku/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run-sudoku", "Run the executable");
    run_step.dependOn(&run_exe.step);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/sudoku/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test-sudoku", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan = try createVulkanModule(b);
    const shaders = try compileShaders(b);

    const exe = b.addExecutable(.{
        .name = "Sudoku",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (b.host.target.os.tag == .windows) {
        exe.addIncludePath(.{ .path = "include/win/" });
        exe.addLibraryPath(.{ .path = "lib/win/" });

        exe.linkSystemLibrary("glfw3dll");
        exe.linkSystemLibrary("vulkan-1");
    } else {
        exe.linkSystemLibrary("glfw");
        exe.linkSystemLibrary("vulkan");
    }

    for (shaders.items) |shader| {
        exe.addAnonymousModule(shader.name, .{ .source_file = shader.data });
    }

    exe.addModule("vulkan", vulkan);
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.host.target.os.tag == .windows) {
        run_cmd.addPathDir("lib/win");
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

    addSudokuBackendTests(b, target, optimize);
}
