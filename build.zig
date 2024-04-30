const std = @import("std");
const glfw = @import("build/glfw.zig");
const vulkan = @import("build/vulkan.zig");
const shaderc = @import("build/shaderc.zig");
const sudoku_backend = @import("build/sudoku_backend.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vm = try vulkan.createVulkanModule(b);
    const shaders = try shaderc.compileShaders(b);

    const exe = b.addExecutable(.{
        .name = "Sudoku",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (b.host.result.os.tag == .windows) {
        vulkan.addIncludePath(exe);
        glfw.addIncludePath(exe);
        exe.addLibraryPath(.{ .path = "ext/win/lib" });

        exe.linkSystemLibrary("glfw3dll");
    } else {
        exe.linkSystemLibrary("glfw");
    }

    exe.linkSystemLibrary("vulkan");

    for (shaders.items) |shader| {
        exe.root_module.addAnonymousImport(shader.name, .{ .root_source_file = shader.data });
    }

    exe.root_module.addImport("vulkan", vm);
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.host.result.os.tag == .windows) {
        run_cmd.addPathDir("ext/win/lib");
    }

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    sudoku_backend.addSudokuExe(b, target, optimize);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    sudoku_backend.addSudokuTests(b, test_step, target, optimize);
}
