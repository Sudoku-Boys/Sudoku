const std = @import("std");
const vk = @import("vk.zig");

const CommandBuffer = @This();

pub const Level = enum {
    Primary,
    Secondary,
};

vk: vk.api.VkCommandBuffer,
pool: vk.api.VkCommandPool,
device: vk.api.VkDevice,
allocator: std.mem.Allocator,

pub fn init(pool: vk.CommandPool, level: Level) !CommandBuffer {
    const vk_level = switch (level) {
        .Primary => vk.api.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .Secondary => vk.api.VK_COMMAND_BUFFER_LEVEL_SECONDARY,
    };

    const bufferInfo = vk.api.VkCommandBufferAllocateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = pool.vk,
        .level = @intCast(vk_level),
        .commandBufferCount = 1,
    };

    var buffer: vk.api.VkCommandBuffer = undefined;
    try vk.check(vk.api.vkAllocateCommandBuffers(pool.device, &bufferInfo, &buffer));

    return .{
        .vk = buffer,
        .pool = pool.vk,
        .device = pool.device,
        .allocator = pool.allocator,
    };
}

pub fn deinit(self: CommandBuffer) void {
    vk.api.vkFreeCommandBuffers(self.device, self.pool, 1, &self.vk);
}

pub fn reset(self: CommandBuffer) !void {
    try vk.check(vk.api.vkResetCommandBuffer(self.vk, 0));
}

pub const Usage = packed struct {
    one_time_submit: bool = false,
    render_pass_continue: bool = false,
    simultaneous_use: bool = false,

    _unused: u5 = 0,

    comptime {
        std.debug.assert(@sizeOf(Usage) == @sizeOf(u8));
    }

    pub fn asBits(self: Usage) u8 {
        return @bitCast(self);
    }
};

pub fn begin(self: CommandBuffer, usage: Usage) !void {
    const beginInfo = vk.api.VkCommandBufferBeginInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = usage.asBits(),
        .pInheritanceInfo = null,
    };

    try vk.check(vk.api.vkBeginCommandBuffer(self.vk, &beginInfo));
}

pub fn end(self: CommandBuffer) !void {
    try vk.check(vk.api.vkEndCommandBuffer(self.vk));
}

pub const CopyBufferDescriptor = struct {
    src: vk.Buffer,
    dst: vk.Buffer,
    src_offset: u64,
    dst_offset: u64,
    size: u64,
};

pub fn copyBuffer(self: CommandBuffer, desc: CopyBufferDescriptor) void {
    const region = vk.api.VkBufferCopy{
        .srcOffset = desc.src_offset,
        .dstOffset = desc.dst_offset,
        .size = desc.size,
    };

    vk.api.vkCmdCopyBuffer(self.vk, desc.src.vk, desc.dst.vk, 1, &region);
}

pub const BufferImageCopy = struct {
    buffer_offset: u64 = 0,
    buffer_row_length: u32,
    buffer_image_height: u32,
    aspect: vk.ImageAspects,
    mip_level: u32 = 0,
    base_array_layer: u32 = 0,
    layer_count: u32 = 1,
    image_offset: vk.Offset3D = .{},
    image_extent: vk.Extent3D,
};

pub const CopyBufferToImageDescriptor = struct {
    src: vk.Buffer,
    dst: vk.Image,
    dst_layout: vk.ImageLayout,
    region: BufferImageCopy,
};

pub fn copyBufferToImage(self: CommandBuffer, desc: CopyBufferToImageDescriptor) void {
    vk.api.vkCmdCopyBufferToImage(
        self.vk,
        desc.src.vk,
        desc.dst.vk,
        @intFromEnum(desc.dst_layout),
        1,
        &vk.api.VkBufferImageCopy{
            .bufferOffset = desc.region.buffer_offset,
            .bufferRowLength = desc.region.buffer_row_length,
            .bufferImageHeight = desc.region.buffer_image_height,
            .imageSubresource = .{
                .aspectMask = @bitCast(desc.region.aspect),
                .mipLevel = desc.region.mip_level,
                .baseArrayLayer = desc.region.base_array_layer,
                .layerCount = desc.region.layer_count,
            },
            .imageOffset = .{
                .x = desc.region.image_offset.x,
                .y = desc.region.image_offset.y,
                .z = desc.region.image_offset.z,
            },
            .imageExtent = .{
                .width = desc.region.image_extent.width,
                .height = desc.region.image_extent.height,
                .depth = desc.region.image_extent.depth,
            },
        },
    );
}

pub const ImageMemoryBarrier = struct {
    src_access: vk.Access,
    dst_access: vk.Access,
    old_layout: vk.ImageLayout,
    new_layout: vk.ImageLayout,
    src_queue_family: u32 = vk.api.VK_QUEUE_FAMILY_IGNORED,
    dst_queue_family: u32 = vk.api.VK_QUEUE_FAMILY_IGNORED,
    image: vk.Image,
    aspect: vk.ImageAspects,
    base_mip_level: u32 = 0,
    level_count: u32 = 1,
    base_array_layer: u32 = 0,
    layer_count: u32 = 1,
};

pub const PipelineBarrierDescriptor = struct {
    src_stage: vk.PipelineStages,
    dst_stage: vk.PipelineStages,
    dependency_flags: vk.Dependencies = .{ .by_region = true },
    image_barriers: []const ImageMemoryBarrier,
};

pub fn pipelineBarrier(
    self: CommandBuffer,
    desc: PipelineBarrierDescriptor,
) !void {
    const imageBarriers: []vk.api.VkImageMemoryBarrier = try self.allocator.alloc(
        vk.api.VkImageMemoryBarrier,
        desc.image_barriers.len,
    );
    defer self.allocator.free(imageBarriers);

    for (desc.image_barriers, 0..) |barrier, i| {
        imageBarriers[i] = vk.api.VkImageMemoryBarrier{
            .sType = vk.api.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .pNext = null,
            .srcAccessMask = @bitCast(barrier.src_access),
            .dstAccessMask = @bitCast(barrier.dst_access),
            .oldLayout = @intFromEnum(barrier.old_layout),
            .newLayout = @intFromEnum(barrier.new_layout),
            .srcQueueFamilyIndex = barrier.src_queue_family,
            .dstQueueFamilyIndex = barrier.dst_queue_family,
            .image = barrier.image.vk,
            .subresourceRange = vk.api.VkImageSubresourceRange{
                .aspectMask = @bitCast(barrier.aspect),
                .baseMipLevel = barrier.base_mip_level,
                .levelCount = barrier.level_count,
                .baseArrayLayer = barrier.base_array_layer,
                .layerCount = barrier.layer_count,
            },
        };
    }

    vk.api.vkCmdPipelineBarrier(
        self.vk,
        @bitCast(desc.src_stage),
        @bitCast(desc.dst_stage),
        @bitCast(desc.dependency_flags),
        0,
        null,
        0,
        null,
        @intCast(desc.image_barriers.len),
        imageBarriers.ptr,
    );
}

pub const RenderArea = struct {
    offset: vk.Offset2D = .{},
    extent: vk.Extent2D,
};

pub const BeginRenderPass = struct {
    render_pass: vk.RenderPass,
    framebuffer: vk.Framebuffer,
    render_area: RenderArea,
};

pub fn beginRenderPass(self: CommandBuffer, desc: BeginRenderPass) void {
    const clear_values: []const vk.api.VkClearValue = &.{
        .{
            .color = .{
                .float32 = .{ 0.0, 0.0, 0.0, 0.0 },
            },
        },
        .{
            .depthStencil = .{
                .depth = 1.0,
                .stencil = 0,
            },
        },
    };

    const renderPassBeginInfo = vk.api.VkRenderPassBeginInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .pNext = null,
        .renderPass = desc.render_pass.vk,
        .framebuffer = desc.framebuffer.vk,
        .renderArea = vk.api.VkRect2D{
            .offset = vk.api.VkOffset2D{
                .x = desc.render_area.offset.x,
                .y = desc.render_area.offset.y,
            },
            .extent = vk.api.VkExtent2D{
                .width = desc.render_area.extent.width,
                .height = desc.render_area.extent.height,
            },
        },
        .clearValueCount = @intCast(clear_values.len),
        .pClearValues = clear_values.ptr,
    };

    vk.api.vkCmdBeginRenderPass(self.vk, &renderPassBeginInfo, vk.api.VK_SUBPASS_CONTENTS_INLINE);
}

pub fn endRenderPass(self: CommandBuffer) void {
    vk.api.vkCmdEndRenderPass(self.vk);
}

pub fn bindGraphicsPipeline(self: CommandBuffer, pipeline: vk.GraphicsPipeline) void {
    vk.api.vkCmdBindPipeline(self.vk, vk.api.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.vk);
}

pub fn bindBindGroup(
    self: CommandBuffer,
    pipeline: vk.GraphicsPipeline,
    index: u32,
    bind_group: vk.BindGroup,
    dynamic_offsets: []u32,
) void {
    vk.api.vkCmdBindDescriptorSets(
        self.vk,
        vk.api.VK_PIPELINE_BIND_POINT_GRAPHICS,
        pipeline.layout,
        index,
        1,
        &bind_group.vk,
        @intCast(dynamic_offsets.len),
        dynamic_offsets.ptr,
    );
}

pub fn bindVertexBuffer(
    self: CommandBuffer,
    binding: u32,
    buffer: vk.Buffer,
    offset: u64,
) void {
    const vk_buffer = buffer.vk;
    vk.api.vkCmdBindVertexBuffers(self.vk, binding, 1, &vk_buffer, &offset);
}

pub fn bindIndexBuffer(
    self: CommandBuffer,
    buffer: vk.Buffer,
    offset: u64,
    index_type: vk.IndexType,
) void {
    vk.api.vkCmdBindIndexBuffer(self.vk, buffer.vk, offset, @intFromEnum(index_type));
}

pub const Viewport = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32,
    height: f32,
    min_depth: f32 = 0.0,
    max_depth: f32 = 1.0,
};

pub fn setViewport(self: CommandBuffer, viewport: Viewport) void {
    const vk_viewport = vk.api.VkViewport{
        .x = viewport.x,
        .y = viewport.y,
        .width = viewport.width,
        .height = viewport.height,
        .minDepth = viewport.min_depth,
        .maxDepth = viewport.max_depth,
    };

    vk.api.vkCmdSetViewport(self.vk, 0, 1, &vk_viewport);
}

pub const Scissor = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

pub fn setScissor(self: CommandBuffer, scissor: Scissor) void {
    const vk_scissor = vk.api.VkRect2D{
        .offset = vk.api.VkOffset2D{
            .x = scissor.x,
            .y = scissor.y,
        },
        .extent = vk.api.VkExtent2D{
            .width = scissor.width,
            .height = scissor.height,
        },
    };

    vk.api.vkCmdSetScissor(self.vk, 0, 1, &vk_scissor);
}

pub const DrawDescriptor = struct {
    vertex_count: u32,
    instance_count: u32 = 1,
    first_vertex: u32 = 0,
    first_instance: u32 = 0,
};

pub fn draw(self: CommandBuffer, desc: DrawDescriptor) void {
    vk.api.vkCmdDraw(
        self.vk,
        desc.vertex_count,
        desc.instance_count,
        desc.first_vertex,
        desc.first_instance,
    );
}

pub const DrawIndexedDescriptor = struct {
    index_count: u32,
    instance_count: u32 = 1,
    first_index: u32 = 0,
    vertex_offset: i32 = 0,
    first_instance: u32 = 0,
};

pub fn drawIndexed(self: CommandBuffer, desc: DrawIndexedDescriptor) void {
    vk.api.vkCmdDrawIndexed(
        self.vk,
        desc.index_count,
        desc.instance_count,
        desc.first_index,
        desc.vertex_offset,
        desc.first_instance,
    );
}
