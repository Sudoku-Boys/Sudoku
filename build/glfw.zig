const std = @import("std");

pub fn addIncludePath(s: *std.Build.Step.Compile) void {
    s.root_module.addIncludePath(.{ .path = "ext/glfw/include" });
}
