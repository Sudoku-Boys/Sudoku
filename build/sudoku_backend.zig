const std = @import("std");

pub fn addSudokuExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) void {
    const exe = b.addExecutable(.{
        .name = "sudoku-backend",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/sudoku/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);
    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());

    const run_step = b.step("run-sudoku", "Run the executable");
    run_step.dependOn(&run_exe.step);
}

pub fn addSudokuTests(b: *std.Build, test_step: *std.Build.Step, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) void {
    const parse_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/sudoku/parse.zig" },
        .target = target,
        .optimize = optimize,
    });

    const solve_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/sudoku/solve.zig" },
        .target = target,
        .optimize = optimize,
    });

    const board_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/sudoku/board.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_parse_tests = b.addRunArtifact(parse_tests);
    const run_solve_tests = b.addRunArtifact(solve_tests);
    const run_board_tests = b.addRunArtifact(board_tests);

    test_step.dependOn(&run_parse_tests.step);
    test_step.dependOn(&run_solve_tests.step);
    test_step.dependOn(&run_board_tests.step);
}
