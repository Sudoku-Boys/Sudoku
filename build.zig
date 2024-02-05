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

    tool.linkSystemLibrary("shaderc_shared");
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
    const shaders = try compileShaders(b);

    const exe = b.addExecutable(.{
        .name = "Sudoku",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (b.host.target.os.tag == .windows) {
        exe.addIncludePath(.{ .path = "include/win/" });
        exe.addLibPath(.{ .path = "lib/win/" });

        exe.linkSystemLibrary("glfw3dll");
        exe.linkSystemLibrary("vulkan-1");
    } else {
        exe.linkSystemLibrary("glfw");
        exe.linkSystemLibrary("vulkan");
    }

    exe.addAnonymousModule("vulkan_enums", .{ .source_file = vulkan_enums });
    exe.addAnonymousModule("vulkan_flags", .{ .source_file = vulkan_flags });

    for (shaders.items) |shader| {
        exe.addAnonymousModule(shader.name, .{ .source_file = shader.data });
    }

    exe.linkLibC();

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
