const std = @import("std");

pub fn addSudokuExe(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) void {
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
}

pub fn addSudokuTests(b: *std.Build, test_step: *std.Build.Step, target: std.zig.CrossTarget, optimize: std.builtin.Mode) void {
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/sudoku/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);
}
