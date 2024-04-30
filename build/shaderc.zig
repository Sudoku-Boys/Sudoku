const std = @import("std");
const builtin = @import("builtin");

const ShaderStage = enum {
    Vertex,
    Fragment,
    Compute,

    fn fromPath(name: []const u8) ?ShaderStage {
        const ext = std.fs.path.extension(name);

        if (std.mem.eql(u8, ext, ".vert")) return .Vertex;
        if (std.mem.eql(u8, ext, ".frag")) return .Fragment;
        if (std.mem.eql(u8, ext, ".comp")) return .Compute;

        return null;
    }

    fn argName(self: ShaderStage) []const u8 {
        switch (self) {
            .Vertex => return "vertex",
            .Fragment => return "fragment",
            .Compute => return "compute",
        }
    }
};

const CompiledShader = struct {
    name: []const u8,
    stage: ShaderStage,
    data: std.Build.LazyPath,
};

fn compileShaderTool(
    b: *std.Build,
) *std.Build.Step.Compile {
    const tool = b.addExecutable(.{
        .target = b.host,
        .name = "compile_shader",
        .root_source_file = .{ .path = "build/vulkan/compile_shader.zig" },
    });

    switch (b.host.result.os.tag) {
        .windows => {
            addWindowsIncludePath(tool);
            tool.addLibraryPath(.{ .path = "ext/win/lib" });
        },
        .linux => {
            if (comptime builtin.os.tag == .linux) {
                addLinuxIncludePath(tool);
            }
        },
        else => {},
    }

    tool.linkSystemLibrary("shaderc_shared");
    tool.linkLibC();

    return tool;
}

fn rebuildDetection(b: *std.Build, run: *std.Build.Step.Run) !void {
    var shaders = try std.fs.cwd().openDir("shaders", .{
        .iterate = true,
    });

    defer shaders.close();

    var it = shaders.iterate();

    while (try it.next()) |entry| {
        const other_path = try std.fs.path.join(b.allocator, &.{ "shaders", entry.name });
        run.addFileArg(.{ .path = other_path });
    }
}

fn compileShader(
    b: *std.Build,
    tool: *std.Build.Step.Compile,
    path: []const u8,
    stage: ShaderStage,
) !std.Build.LazyPath {
    const tool_step = b.addRunArtifact(tool);
    tool_step.addFileArg(.{ .path = path });
    tool_step.addArg(stage.argName());

    try rebuildDetection(b, tool_step);

    if (b.host.result.os.tag == .windows) {
        tool_step.addPathDir("ext/win/lib");
    }

    return tool_step.captureStdOut();
}

pub fn compileShaders(
    b: *std.Build,
) !std.ArrayList(CompiledShader) {
    const tool = compileShaderTool(b);

    var dir = try std.fs.cwd().openDir("shaders", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();

    var shaders = std.ArrayList(CompiledShader).init(b.allocator);

    while (try it.next()) |entry| {
        if (ShaderStage.fromPath(entry.name)) |stage| {
            const path = try std.mem.join(b.allocator, "/", &.{ "shaders", entry.name });
            const data = try compileShader(b, tool, path, stage);

            try shaders.append(CompiledShader{
                .name = path,
                .stage = stage,
                .data = data,
            });
        }
    }

    return shaders;
}

pub fn addWindowsIncludePath(s: *std.Build.Step.Compile) void {
    s.addIncludePath(.{ .path = "ext/shaderc/libshaderc/include" });
}

pub fn addLinuxIncludePath(s: *std.Build.Step.Compile) void {
    if (std.posix.getenv("LD_LIBRARY_PATH")) |ld_library_path| {
        var it = std.mem.splitScalar(u8, ld_library_path, ':');

        while (it.next()) |path| {
            s.addLibraryPath(.{ .path = path });
        }
    }
}
