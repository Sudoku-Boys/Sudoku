const std = @import("std");
const vk = @import("vk.zig");
const Window = @import("../engine/Window.zig");

const Swapchain = @This();

fn pickSurfaceFormat(formats: []vk.api.VkSurfaceFormatKHR) vk.api.VkSurfaceFormatKHR {
    for (formats) |format| {
        if (format.format == vk.api.VK_FORMAT_B8G8R8A8_SRGB) {
            return format;
        }
    }

    return formats[0];
}

fn pickPresentMode(present_modes: []vk.api.VkPresentModeKHR) vk.api.VkPresentModeKHR {
    for (present_modes) |mode| {
        if (mode == vk.api.VK_PRESENT_MODE_FIFO_KHR) {
            return mode;
        }
    }

    return present_modes[0];
}

fn createImageViews(
    device: vk.api.VkDevice,
    format: vk.api.VkFormat,
    images: []const vk.api.VkImage,
    views: []vk.ImageView,
) !void {
    for (images, 0..) |image, i| {
        // we just create all the views, this is a simple operation
        views[i] = try vk.ImageView.fromVk(device, image, .{
            .view_type = .Image2D,
            .format = format,
        });
    }
}

fn createFramebuffers(
    device: vk.Device,
    render_pass: vk.RenderPass,
    extent: vk.api.VkExtent2D,
    views: []const vk.ImageView,
    framebuffers: []vk.Framebuffer,
) !void {
    for (views, 0..) |view, i| {
        framebuffers[i] = try vk.Framebuffer.init(device, .{
            .render_pass = render_pass,
            .attachments = &.{view},
            .width = extent.width,
            .height = extent.height,
            .layers = 1,
        });
    }
}

const SwapchainInfo = struct {
    image_count: u32,
    present_mode: vk.api.VkPresentModeKHR,
    format: vk.api.VkFormat,
    color_space: vk.api.VkColorSpaceKHR,
    extent: vk.api.VkExtent2D,
    pre_transform: vk.api.VkSurfaceTransformFlagBitsKHR,

    fn query(support: vk.Device.SwapchainSupport) SwapchainInfo {
        const format = pickSurfaceFormat(support.formats);
        const present_mode = pickPresentMode(support.present_modes);
        const extent = support.capabilities.currentExtent;
        const image_count = @min(
            support.capabilities.minImageCount + 1,
            support.capabilities.maxImageCount,
        );
        const pre_transform = support.capabilities.currentTransform;

        return .{
            .image_count = image_count,
            .present_mode = present_mode,
            .format = format.format,
            .color_space = format.colorSpace,
            .extent = extent,
            .pre_transform = pre_transform,
        };
    }
};

fn createSwapchain(
    device: vk.Device,
    info: SwapchainInfo,
    surface: vk.api.VkSurfaceKHR,
    old_swapchain: ?vk.api.VkSwapchainKHR,
) !vk.api.VkSwapchainKHR {
    // create the actual swapchain
    var swapchain_info = vk.api.VkSwapchainCreateInfoKHR{
        .sType = vk.api.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .pNext = null,
        .flags = 0,
        .surface = surface,
        .minImageCount = info.image_count,
        .imageFormat = info.format,
        .imageColorSpace = info.color_space,
        .imageExtent = info.extent,
        .imageArrayLayers = 1,
        // we want to render directly to the images, as well as copy to them
        .imageUsage = vk.api.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
            vk.api.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        // these are set later! (see below)
        .imageSharingMode = undefined,
        .queueFamilyIndexCount = undefined,
        .pQueueFamilyIndices = undefined,
        .preTransform = info.pre_transform,
        .compositeAlpha = vk.api.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = info.present_mode,
        .clipped = vk.api.VK_FALSE,
        .oldSwapchain = if (old_swapchain) |swapchain| swapchain else null,
    };

    // use exlusive mode if possible, as it's faster
    if (device.queues.graphics != device.queues.present) {
        // if the graphics and present queues are different, we need to use concurrent mode
        // to allow the images to be used across multiple queues
        //
        // this sucks because it's slower...
        swapchain_info.imageSharingMode = vk.api.VK_SHARING_MODE_CONCURRENT;
        swapchain_info.queueFamilyIndexCount = 2;
        swapchain_info.pQueueFamilyIndices = &device.queues.indices();
    } else {
        swapchain_info.imageSharingMode = vk.api.VK_SHARING_MODE_EXCLUSIVE;

        // these are ignored in exclusive mode
        swapchain_info.queueFamilyIndexCount = 0;
        swapchain_info.pQueueFamilyIndices = null;
    }

    var swapchain: vk.api.VkSwapchainKHR = undefined;
    try vk.check(vk.api.vkCreateSwapchainKHR(device.vk, &swapchain_info, null, &swapchain));

    return swapchain;
}

vk: vk.api.VkSwapchainKHR,
surface: vk.api.VkSurfaceKHR,

render_pass: vk.RenderPass,
device: vk.Device,

extent: vk.api.VkExtent2D,

images: []vk.api.VkImage,
views: []vk.ImageView,
framebuffers: []vk.Framebuffer,

pub fn init(
    device: vk.Device,
    window: Window,
) !Swapchain {
    const support = try vk.Device.SwapchainSupport.query(device.allocator, device.physical, window.surface);
    defer support.deinit();

    const info = SwapchainInfo.query(support);

    const swapchain = try createSwapchain(device, info, window.surface, null);
    errdefer vk.api.vkDestroySwapchainKHR(device.vk, swapchain, null);

    // get the image count from the swapchain
    var images_count: u32 = 0;
    try vk.check(vk.api.vkGetSwapchainImagesKHR(device.vk, swapchain, &images_count, null));

    var images = try device.allocator.alloc(vk.api.VkImage, images_count);
    errdefer device.allocator.free(images);

    const render_pass = try vk.RenderPass.init(
        device,
        .{
            .attachments = &.{.{
                .format = info.format,
                .samples = 1,
                .load_op = .Clear,
                .store_op = .Store,
                .final_layout = .PresentSrc,
            }},
            .subpasses = &.{.{
                .color_attachments = &.{.{
                    .attachment = 0,
                    .layout = .ColorAttachmentOptimal,
                }},
            }},
            .dependencies = &.{.{
                .src_subpass = vk.SUBPASS_EXTERNAL,
                .dst_subpass = 0,
                .src_stage_mask = .{ .color_attachment_output = true },
                .dst_stage_mask = .{ .color_attachment_output = true },
                .dst_access_mask = .{ .color_attachment_write = true },
            }},
        },
    );
    errdefer render_pass.deinit();

    // get the actual images
    try vk.check(vk.api.vkGetSwapchainImagesKHR(device.vk, swapchain, &images_count, images.ptr));

    var views = try device.allocator.alloc(vk.ImageView, images_count);
    errdefer device.allocator.free(views);
    var framebuffers = try device.allocator.alloc(vk.Framebuffer, images_count);
    errdefer device.allocator.free(framebuffers);

    try createImageViews(device.vk, info.format, images, views);
    try createFramebuffers(device, render_pass, info.extent, views, framebuffers);

    return .{
        .vk = swapchain,
        .surface = window.surface,

        .device = device,
        .render_pass = render_pass,

        .extent = info.extent,

        .images = images,
        .views = views,
        .framebuffers = framebuffers,
    };
}

pub fn deinit(self: Swapchain) void {
    for (self.framebuffers) |framebuffer| {
        framebuffer.deinit();
    }

    // deinit views
    for (self.views) |view| {
        view.deinit();
    }

    // deinit swapchain
    vk.api.vkDestroySwapchainKHR(self.device.vk, self.vk, null);

    // deinit render pass
    self.render_pass.deinit();

    // free memory
    self.device.allocator.free(self.images);
    self.device.allocator.free(self.views);
    self.device.allocator.free(self.framebuffers);
}

pub fn recreate(self: *Swapchain) !void {
    try self.device.waitIdle();

    for (self.framebuffers) |framebuffer| {
        framebuffer.deinit();
    }

    for (self.views) |view| {
        view.deinit();
    }

    const support = try vk.Device.SwapchainSupport.query(self.device.allocator, self.device.physical, self.surface);
    defer support.deinit();

    const info = SwapchainInfo.query(support);

    const swapchain = try createSwapchain(self.device, info, self.surface, self.vk);
    errdefer vk.api.vkDestroySwapchainKHR(self.device.vk, swapchain, null);

    vk.api.vkDestroySwapchainKHR(self.device.vk, self.vk, null);

    self.vk = swapchain;

    var images_count: u32 = 0;
    try vk.check(vk.api.vkGetSwapchainImagesKHR(self.device.vk, swapchain, &images_count, null));

    var images = try self.device.allocator.realloc(self.images, images_count);
    errdefer self.device.allocator.free(images);

    try vk.check(vk.api.vkGetSwapchainImagesKHR(self.device.vk, swapchain, &images_count, images.ptr));

    var views = try self.device.allocator.realloc(self.views, images_count);
    errdefer self.device.allocator.free(views);
    var framebuffers = try self.device.allocator.realloc(self.framebuffers, images_count);
    errdefer self.device.allocator.free(framebuffers);

    try createImageViews(self.device.vk, info.format, images, views);
    try createFramebuffers(self.device, self.render_pass, info.extent, views, framebuffers);

    self.extent = info.extent;
}

pub fn aquireNextImage(
    self: Swapchain,
    desc: struct {
        semaphore: ?vk.Semaphore = null,
        fence: ?vk.Fence = null,
        timeout: u64 = std.math.maxInt(u64),
    },
) !u32 {
    var image_index: u32 = 0;
    try vk.check(vk.api.vkAcquireNextImageKHR(
        self.device.vk,
        self.vk,
        desc.timeout,
        if (desc.semaphore) |semaphore| semaphore.vk else null,
        if (desc.fence) |fence| fence.vk else null,
        &image_index,
    ));
    return image_index;
}
