const std = @import("std");

const c = @cImport({
    @cInclude("shaderc/shaderc.h");
});

const Error = error{
    InvalidArgument,
    ExpectedIncludePath,
    ShadercError,
};

const INCLUDE_DIRECTIVE = "#include";

const ShaderProcessor = struct {
    allocator: std.mem.Allocator,
    included_files: std.ArrayList([]const u8),
    output: std.ArrayList(u8),

    fn init(allocator: std.mem.Allocator) ShaderProcessor {
        return ShaderProcessor{
            .allocator = allocator,
            .included_files = std.ArrayList([]const u8).init(allocator),
            .output = std.ArrayList(u8).init(allocator),
        };
    }

    fn deinit(self: ShaderProcessor) void {
        self.included_files.deinit();
        self.output.deinit();
    }

    fn trimWhitespace(input: []const u8) []const u8 {
        var start: usize = 0;
        var end: usize = input.len;

        while (start < end and std.ascii.isWhitespace(input[start])) {
            start += 1;
        }

        while (end > start and std.ascii.isWhitespace(input[end - 1])) {
            end -= 1;
        }

        return input[start..end];
    }

    fn trimIncludePath(input: []const u8) ![]const u8 {
        const trimmed = trimWhitespace(input);

        if (trimmed[0] != '"' or trimmed[trimmed.len - 1] != '"') {
            return error.ExpectedIncludePath;
        }

        return trimmed[1 .. trimmed.len - 1];
    }

    fn process(self: *ShaderProcessor, path: []const u8) !void {
        for (self.included_files.items) |file| {
            if (std.mem.eql(u8, file, path)) return;
        }

        const source = try std.fs.cwd().readFileAlloc(
            self.allocator,
            path,
            std.math.maxInt(usize),
        );

        try self.included_files.append(path);

        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, INCLUDE_DIRECTIVE)) {
                const include_path = std.mem.trimLeft(u8, line, INCLUDE_DIRECTIVE);
                const trimmed = try trimIncludePath(include_path);

                for (self.included_files.items) |file| {
                    if (std.mem.eql(u8, file, trimmed)) {
                        continue;
                    }
                }

                const dir = std.fs.path.dirname(path) orelse return error.ExpectedIncludePath;
                const full_path = try std.fs.path.join(
                    self.allocator,
                    &.{ dir, trimmed },
                );

                try self.process(full_path);
            } else {
                try self.output.appendSlice(line);
                try self.output.append('\n');
            }
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 3) return error.InvalidArgument;

    var processor = ShaderProcessor.init(allocator);
    defer processor.deinit();

    try processor.process(args[1]);

    const compiler = c.shaderc_compiler_initialize();
    if (compiler == null) return error.ShadercError;
    defer c.shaderc_compiler_release(compiler);

    const options = c.shaderc_compile_options_initialize();
    defer c.shaderc_compile_options_release(options);

    c.shaderc_compile_options_set_optimization_level(
        options,
        c.shaderc_optimization_level_performance,
    );
    c.shaderc_compile_options_set_target_env(
        options,
        c.shaderc_target_env_vulkan,
        c.shaderc_env_version_vulkan_1_0,
    );

    var kind: c_uint = c.shaderc_glsl_vertex_shader;

    if (std.mem.eql(u8, args[2], "fragment")) {
        kind = c.shaderc_glsl_fragment_shader;
    }

    const result = c.shaderc_compile_into_spv(
        compiler,
        processor.output.items.ptr,
        processor.output.items.len,
        kind,
        args[1],
        "main",
        options,
    );
    defer c.shaderc_result_release(result);

    if (c.shaderc_result_get_compilation_status(result) != c.shaderc_compilation_status_success) {
        const error_message = c.shaderc_result_get_error_message(result);
        std.debug.print("Compilation error: {s}\n", .{error_message});
        return error.ShadercError;
    }

    const spirv_size = c.shaderc_result_get_length(result);
    const spirv_data = c.shaderc_result_get_bytes(result);

    const stdout = std.io.getStdOut();
    defer stdout.close();

    try stdout.writeAll(spirv_data[0..spirv_size]);
}
