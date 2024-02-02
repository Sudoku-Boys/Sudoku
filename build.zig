const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Sudoku",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (b.host.target.os.tag == std.Target.Os.Tag.windows) {
        exe.addIncludePath(.{.path = "include/win"});
        exe.addLibraryPath(.{.path = "lib/win"});
        exe.linkSystemLibrary("glfw3dll");
        exe.linkSystemLibrary("vulkan-1");
    } else if (b.host.target.os.tag == std.Target.Os.Tag.linux) {
        exe.linkSystemLibrary("glfw");
        exe.linkSystemLibrary("vulkan");
    } else {
        std.debug.panic("Unsupported OS\n", .{});
    }

    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.host.target.os.tag == std.Target.Os.Tag.windows) {
        run_cmd.addPathDir("lib/win");
    } else if (b.host.target.os.tag == std.Target.Os.Tag.linux) {
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
