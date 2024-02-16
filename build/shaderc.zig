const std = @import("std");

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
        addIncludePath(tool);
        tool.addLibraryPath(.{ .path = "ext/win/lib" });
    }

    tool.linkSystemLibrary("shaderc_shared");
    tool.linkLibC();

    return tool;
}

fn rebuildDetection(b: *std.Build, run: *std.Build.RunStep) !void {
    var shaders = try std.fs.cwd().openIterableDir("shaders", .{});
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

    if (b.host.target.os.tag == .windows) {
        tool_step.addPathDir("ext/win/lib");
    }

    return tool_step.captureStdOut();
}

pub fn compileShaders(
    b: *std.Build,
) !std.ArrayList(CompiledShader) {
    const tool = compileShaderTool(b);

    const dir = std.fs.cwd();
    var shader = try dir.openIterableDir("shaders", .{});
    defer shader.close();

    var shaders = std.ArrayList(CompiledShader).init(b.allocator);

    var it = shader.iterate();
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

pub fn addIncludePath(s: *std.Build.Step.Compile) void {
    s.addIncludePath(.{ .path = "ext/shaderc/libshaderc/include" });
}
