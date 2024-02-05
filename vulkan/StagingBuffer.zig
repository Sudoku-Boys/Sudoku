const std = @import("std");
const vk = @import("vk.zig");

const StagingBuffer = @This();

const INITIAL_SIZE: usize = 4 * 1024 * 1024;

pub const Error = error{
    UnsupportedLayout,
};

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

    const command = try pool.alloc(.Primary);

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

pub const CopyBufferDescriptor = struct {
    dst: vk.Buffer,
    src_offset: u64 = 0,
    dst_offset: u64 = 0,
    size: u64,
};

pub fn copyBuffer(self: StagingBuffer, desc: CopyBufferDescriptor) !void {
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

pub const CopyImageDescriptor = struct {
    dst: vk.Image,
    aspect: vk.ImageAspects,
    mip_level: u32 = 0,
    base_array_layer: u32 = 0,
    layer_count: u32 = 1,
    old_layout: vk.ImageLayout,
    extent: vk.Extent3D,
    offset: vk.Offset3D = .{},
};

// transsition the image to general
fn recordTransitionImage(
    self: StagingBuffer,
    desc: CopyImageDescriptor,
) !void {
    var src_stage: vk.PipelineStages = .{};
    var dst_stage: vk.PipelineStages = .{};
    var src_access: vk.Access = .{};
    var dst_access: vk.Access = .{};

    switch (desc.old_layout) {
        .Undefined => {
            src_stage.top_of_pipe = true;
            dst_stage.transfer = true;

            dst_access.transfer_write = true;
        },
        .ShaderReadOnlyOptimal => {
            src_stage.fragment_shader = true;
            dst_stage.transfer = true;

            src_access.shader_read = true;
            dst_access.transfer_write = true;
        },
        .TransferDstOptimal => return,
        else => return error.UnsupportedLayout,
    }

    try self.command.pipelineBarrier(.{
        .src_stage = src_stage,
        .dst_stage = dst_stage,
        .image_barriers = &.{.{
            .src_access = src_access,
            .dst_access = dst_access,
            .old_layout = desc.old_layout,
            .new_layout = .TransferDstOptimal,
            .image = desc.dst,
            .aspect = desc.aspect,
            .base_mip_level = desc.mip_level,
            .level_count = 1,
            .base_array_layer = desc.base_array_layer,
            .layer_count = desc.layer_count,
        }},
    });
}

pub fn copyImage(self: StagingBuffer, desc: CopyImageDescriptor) !void {
    try self.command.reset();
    try self.command.begin(.{ .one_time_submit = true });

    try self.recordTransitionImage(desc);

    self.command.copyBufferToImage(.{
        .src = self.buffer,
        .dst = desc.dst,
        .dst_layout = .TransferDstOptimal,
        .region = .{
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .aspect = desc.aspect,
            .mip_level = desc.mip_level,
            .base_array_layer = desc.base_array_layer,
            .layer_count = desc.layer_count,
            .image_extent = desc.extent,
            .image_offset = desc.offset,
        },
    });

    try self.command.end();

    try self.device.graphics.submit(.{
        .command_buffers = &.{
            self.command,
        },
    });

    try self.device.graphics.waitIdle();
}
