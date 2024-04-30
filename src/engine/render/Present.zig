const std = @import("std");
const vk = @import("vulkan");

const asset = @import("../asset.zig");
const system = @import("../system.zig");

const Sdr = @import("Sdr.zig");

const Present = @This();

graphics_buffer: vk.CommandBuffer,

in_flight: vk.Fence,
image_available: vk.Semaphore,
render_finished: vk.Semaphore,

pub fn init(device: vk.Device, graphics_pool: vk.CommandPool) !Present {
    const graphics_buffer = try graphics_pool.alloc(.Primary);
    errdefer graphics_buffer.deinit();

    const in_flight = try device.createFence(true);
    errdefer in_flight.deinit();

    const image_available = try device.createSemaphore();
    errdefer image_available.deinit();

    const render_finished = try device.createSemaphore();
    errdefer render_finished.deinit();

    return .{
        .graphics_buffer = graphics_buffer,

        .in_flight = in_flight,
        .image_available = image_available,
        .render_finished = render_finished,
    };
}

pub fn deinit(self: Present) void {
    self.graphics_buffer.deinit();
    self.in_flight.deinit();
    self.image_available.deinit();
    self.render_finished.deinit();
}
