const std = @import("std");

pub fn addIncludePath(s: *std.Build.Step.Compile) void {
    s.addIncludePath(.{ .path = "ext/glfw/include" });
}
