const std = @import("std");
const vk = @import("vk");

const Engine = @import("../Engine.zig");
const Renderer = @import("Renderer.zig");

const Plugin = @This();

device: vk.Device,
surface: vk.Surface,
present_mode: vk.PresentMode,

pub fn buildPlugin(self: Plugin, engine: *Engine) !void {
    _ = engine;
    _ = self;
}
