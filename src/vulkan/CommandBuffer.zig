const std = @import("std");
const vk = @import("vk.zig");

const CommandBuffer = @This();

pub const Level = enum {
    Primary,
    Secondary,
};

pub const RenderArea = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 1,
    height: u32 = 1,
};

pub const Viewport = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,
    min_depth: f32 = 0.0,
    max_depth: f32 = 1.0,
};

pub const Scissor = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

pub const BeginRenderPass = struct {
    render_pass: vk.RenderPass,
    framebuffer: vk.Framebuffer,
    render_area: RenderArea = .{},
};

vk: vk.api.VkCommandBuffer,
device: vk.api.VkDevice,

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
        .device = pool.device,
    };
}

pub fn reset(self: CommandBuffer) !void {
    try vk.check(vk.api.vkResetCommandBuffer(self.vk, 0));
}

pub fn begin(self: CommandBuffer) !void {
    const beginInfo = vk.api.VkCommandBufferBeginInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = 0,
        .pInheritanceInfo = null,
    };

    try vk.check(vk.api.vkBeginCommandBuffer(self.vk, &beginInfo));
}

pub fn end(self: CommandBuffer) !void {
    try vk.check(vk.api.vkEndCommandBuffer(self.vk));
}

pub fn beginRenderPass(self: CommandBuffer, desc: BeginRenderPass) void {
    const clear: vk.api.VkClearValue = .{
        .color = .{
            .float32 = .{ 0.0, 0.0, 0.0, 0.0 },
        },
    };

    const renderPassBeginInfo = vk.api.VkRenderPassBeginInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .pNext = null,
        .renderPass = desc.render_pass.vk,
        .framebuffer = desc.framebuffer.vk,
        .renderArea = vk.api.VkRect2D{
            .offset = vk.api.VkOffset2D{
                .x = desc.render_area.x,
                .y = desc.render_area.y,
            },
            .extent = vk.api.VkExtent2D{
                .width = desc.render_area.width,
                .height = desc.render_area.height,
            },
        },
        .clearValueCount = 1,
        .pClearValues = &clear,
    };

    vk.api.vkCmdBeginRenderPass(self.vk, &renderPassBeginInfo, vk.api.VK_SUBPASS_CONTENTS_INLINE);
}

pub fn endRenderPass(self: CommandBuffer) void {
    vk.api.vkCmdEndRenderPass(self.vk);
}

pub fn bindGraphicsPipeline(self: CommandBuffer, pipeline: vk.GraphicsPipeline) void {
    vk.api.vkCmdBindPipeline(self.vk, vk.api.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.vk);
}

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

pub fn draw(
    self: CommandBuffer,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
) void {
    vk.api.vkCmdDraw(
        self.vk,
        vertex_count,
        instance_count,
        first_vertex,
        first_instance,
    );
}
