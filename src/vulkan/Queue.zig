const std = @import("std");
const vk = @import("vk.zig");

const Queue = @This();

vk: vk.api.VkQueue,
allocator: std.mem.Allocator,

pub fn waitIdle(self: Queue) !void {
    try vk.check(vk.api.vkQueueWaitIdle(self.vk));
}

pub const WaitSemaphore = struct {
    semaphore: vk.Semaphore,
    stage: vk.PipelineStages,
};

pub const SubmitDescriptor = struct {
    wait_semaphores: []const WaitSemaphore = &.{},
    command_buffers: []const vk.CommandBuffer = &.{},
    signal_semaphores: []const vk.Semaphore = &.{},
    fence: ?vk.Fence = null,
};

pub fn submit(self: Queue, desc: SubmitDescriptor) !void {
    const wait_semaphores = try self.allocator.alloc(vk.api.VkSemaphore, desc.wait_semaphores.len);
    defer self.allocator.free(wait_semaphores);

    const wait_stages = try self.allocator.alloc(vk.api.VkPipelineStageFlags, desc.wait_semaphores.len);
    defer self.allocator.free(wait_stages);

    const command_buffers = try self.allocator.alloc(vk.api.VkCommandBuffer, desc.command_buffers.len);
    defer self.allocator.free(command_buffers);

    const signal_semaphores = try self.allocator.alloc(vk.api.VkSemaphore, desc.signal_semaphores.len);
    defer self.allocator.free(signal_semaphores);

    for (desc.wait_semaphores, 0..) |semaphore, i| {
        wait_semaphores.ptr[i] = semaphore.semaphore.vk;
        wait_stages.ptr[i] = @bitCast(semaphore.stage);
    }

    for (desc.command_buffers, 0..) |command_buffer, i| {
        command_buffers.ptr[i] = command_buffer.vk;
    }

    for (desc.signal_semaphores, 0..) |semaphore, i| {
        signal_semaphores.ptr[i] = semaphore.vk;
    }

    const submitInfo = vk.api.VkSubmitInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = @intCast(wait_semaphores.len),
        .pWaitSemaphores = wait_semaphores.ptr,
        .pWaitDstStageMask = wait_stages.ptr,
        .commandBufferCount = @intCast(command_buffers.len),
        .pCommandBuffers = command_buffers.ptr,
        .signalSemaphoreCount = @intCast(signal_semaphores.len),
        .pSignalSemaphores = signal_semaphores.ptr,
    };

    const fence = if (desc.fence) |fence| fence.vk else null;
    try vk.check(vk.api.vkQueueSubmit(self.vk, 1, &submitInfo, fence));
}

pub const PresentSwapchain = struct {
    swapchain: vk.Swapchain,
    image: u32,
};

pub const PresentDescriptor = struct {
    wait_semaphores: []const vk.Semaphore = &.{},
    swapchains: []const PresentSwapchain = &.{},
};

pub fn present(self: Queue, desc: PresentDescriptor) !void {
    const wait_semaphores = try self.allocator.alloc(vk.api.VkSemaphore, desc.wait_semaphores.len);
    defer self.allocator.free(wait_semaphores);

    const swapchains = try self.allocator.alloc(vk.api.VkSwapchainKHR, desc.swapchains.len);
    defer self.allocator.free(swapchains);

    const image_indices = try self.allocator.alloc(u32, desc.swapchains.len);
    defer self.allocator.free(image_indices);

    for (desc.wait_semaphores, 0..) |semaphore, i| {
        wait_semaphores.ptr[i] = semaphore.vk;
    }

    for (desc.swapchains, 0..) |swapchain, i| {
        swapchains.ptr[i] = swapchain.swapchain.vk;
        image_indices.ptr[i] = swapchain.image;
    }

    const presentInfo = vk.api.VkPresentInfoKHR{
        .sType = vk.api.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pNext = null,
        .waitSemaphoreCount = @intCast(wait_semaphores.len),
        .pWaitSemaphores = wait_semaphores.ptr,
        .swapchainCount = @intCast(swapchains.len),
        .pSwapchains = swapchains.ptr,
        .pImageIndices = image_indices.ptr,
        .pResults = null,
    };

    try vk.check(vk.api.vkQueuePresentKHR(self.vk, &presentInfo));
}
