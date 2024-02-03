const std = @import("std");
const vk = @import("vk.zig");

const StagingBuffer = @This();

const INITIAL_SIZE: usize = 4 * 1024 * 1024;

buffer: vk.Buffer,
command: vk.CommandBuffer,
size: usize,
device: vk.Device,

pub fn init(device: vk.Device, pool: vk.CommandPool) !StagingBuffer {
    std.debug.assert(pool.kind == .Graphics);

    const buffer = try device.createBuffer(.{
        .size = INITIAL_SIZE,
        .usage = .{ .transfer_src = true },
        .memory = .{ .host_visible = true, .host_coherent = true },
    });

    const command = try pool.createCommandBuffer(.Primary);

    return .{
        .buffer = buffer,
        .command = command,
        .size = INITIAL_SIZE,
        .device = device,
    };
}

pub fn deinit(self: StagingBuffer) void {
    self.buffer.deinit();
    self.command.deinit();
}

pub fn resize(self: *StagingBuffer, size: usize) !void {
    if (size <= self.size) {
        return;
    }

    self.buffer.deinit();

    self.buffer = try self.device.createBuffer(.{
        .size = size,
        .usage = .{ .transfer_src = true },
        .memory = .{ .host_visible = true, .host_coherent = true },
    });

    self.size = size;
}

fn asBytes(data: anytype) []const u8 {
    return switch (@typeInfo(@TypeOf(data))) {
        .Pointer => |ptr| {
            const element_size = @sizeOf(ptr.child);

            switch (ptr.size) {
                .One => {
                    const new_len = element_size;
                    return @as([*]const u8, @ptrCast(data))[0..new_len];
                },
                .Slice => {
                    const new_len = data.len * element_size;
                    return @as([*]const u8, @ptrCast(data.ptr))[0..new_len];
                },
                else => @compileError("Unsupported type for StagingBuffer.write()"),
            }
        },
        else => @compileError("Unsupported type for StagingBuffer.write()"),
    };
}

pub fn write(self: *StagingBuffer, data: anytype) !void {
    const bytes = asBytes(data);

    if (bytes.len > self.size) {
        try self.resize(bytes.len);
    }

    const mem = try self.buffer.map(.{
        .offset = 0,
        .size = bytes.len,
    });

    @memcpy(mem, bytes);

    self.buffer.unmap();
}

pub const CopyDescriptor = struct {
    dst: vk.Buffer,
    src_offset: u64 = 0,
    dst_offset: u64 = 0,
    size: u64,
};

pub fn copy(self: StagingBuffer, desc: CopyDescriptor) !void {
    std.debug.assert(desc.dst.usage.transfer_dst);

    try self.command.reset();
    try self.command.begin(.{ .one_time_submit = true });

    self.command.copyBuffer(.{
        .src = self.buffer,
        .dst = desc.dst,
        .src_offset = desc.src_offset,
        .dst_offset = desc.dst_offset,
        .size = desc.size,
    });

    try self.command.end();

    try self.device.graphics.submit(.{
        .command_buffers = &.{
            self.command,
        },
    });

    try self.device.graphics.waitIdle();
}
