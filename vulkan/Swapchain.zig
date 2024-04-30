const std = @import("std");
const vk = @import("vk.zig");

const Swapchain = @This();

fn pickSurfaceFormat(
    formats: []vk.api.VkSurfaceFormatKHR,
    desired_format: vk.api.VkFormat,
) vk.api.VkSurfaceFormatKHR {
    for (formats) |format| {
        if (format.format == desired_format) {
            return format;
        }
    }

    return formats[0];
}

fn pickPresentMode(
    present_modes: []vk.api.VkPresentModeKHR,
    desired_mode: vk.api.VkPresentModeKHR,
) vk.api.VkPresentModeKHR {
    for (present_modes) |mode| {
        if (mode == desired_mode) {
            return mode;
        }
    }

    return present_modes[0];
}

fn createImageViews(
    device: vk.api.VkDevice,
    extent: vk.Extent3D,
    format: vk.ImageFormat,
    images: []const vk.api.VkImage,
    views: []vk.ImageView,
) !void {
    for (images, 0..) |image, i| {
        const view_info = vk.api.VkImageViewCreateInfo{
            .sType = vk.api.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .image = image,
            .viewType = vk.api.VK_IMAGE_VIEW_TYPE_2D,
            .format = @intFromEnum(format),
            .components = vk.api.VkComponentMapping{
                .r = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = vk.api.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = vk.api.VkImageSubresourceRange{
                .aspectMask = vk.api.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        var image_view: vk.api.VkImageView = undefined;
        try vk.check(vk.api.vkCreateImageView(device, &view_info, null, &image_view));

        // we just create all the views, this is a simple operation
        views[i] = .{
            .vk = image_view,
            .device = device,

            .format = format,
            .extent = extent,
            .type = .Image2D,
            .mip_levels = 1,
            .array_layers = 1,
            .samples = 1,
        };
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
            .extent = extent,
            .layers = 1,
        });
    }
}

const CreatedSwapchain = struct {
    swapchain: vk.api.VkSwapchainKHR,
    format: vk.ImageFormat,
    present_mode: vk.PresentMode,
    extent: vk.Extent3D,
};

fn createSwapchain(
    device: vk.Device,
    format: vk.ImageFormat,
    present_mode: vk.PresentMode,
    surface: vk.api.VkSurfaceKHR,
    old_swapchain: vk.api.VkSwapchainKHR,
) !CreatedSwapchain {
    var capabilities: vk.api.VkSurfaceCapabilitiesKHR = undefined;
    try vk.check(vk.api.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
        device.physical,
        surface,
        &capabilities,
    ));

    capabilities.currentExtent.width = @max(1, capabilities.currentExtent.width);
    capabilities.currentExtent.height = @max(1, capabilities.currentExtent.height);

    if (capabilities.currentExtent.width > capabilities.maxImageExtent.width) {
        capabilities.currentExtent.width = 800;
    }

    if (capabilities.currentExtent.height > capabilities.maxImageExtent.height) {
        capabilities.currentExtent.height = 600;
    }

    const min_image_count = @min(
        capabilities.minImageCount + 1,
        capabilities.maxImageCount,
    );

    var formats_count: u32 = 0;
    try vk.check(vk.api.vkGetPhysicalDeviceSurfaceFormatsKHR(
        device.physical,
        surface,
        &formats_count,
        null,
    ));

    const formats = try device.allocator.alloc(vk.api.VkSurfaceFormatKHR, formats_count);
    defer device.allocator.free(formats);

    try vk.check(vk.api.vkGetPhysicalDeviceSurfaceFormatsKHR(
        device.physical,
        surface,
        &formats_count,
        formats.ptr,
    ));

    var present_modes_count: u32 = 0;
    try vk.check(vk.api.vkGetPhysicalDeviceSurfacePresentModesKHR(
        device.physical,
        surface,
        &present_modes_count,
        null,
    ));

    const present_modes = try device.allocator.alloc(vk.api.VkPresentModeKHR, present_modes_count);
    defer device.allocator.free(present_modes);

    try vk.check(vk.api.vkGetPhysicalDeviceSurfacePresentModesKHR(
        device.physical,
        surface,
        &present_modes_count,
        present_modes.ptr,
    ));

    const vk_format = pickSurfaceFormat(formats, @intFromEnum(format));
    const vk_present_mode = pickPresentMode(present_modes, @intFromEnum(present_mode));

    // create the actual swapchain
    var swapchain_info = vk.api.VkSwapchainCreateInfoKHR{
        .sType = vk.api.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .pNext = null,
        .flags = 0,
        .surface = surface,
        .minImageCount = min_image_count,
        .imageFormat = vk_format.format,
        .imageColorSpace = vk_format.colorSpace,
        .imageExtent = capabilities.currentExtent,
        .imageArrayLayers = 1,
        // we want to render directly to the images, as well as copy to them
        .imageUsage = vk.api.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
            vk.api.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        // these are set later! (see below)
        .imageSharingMode = undefined,
        .queueFamilyIndexCount = undefined,
        .pQueueFamilyIndices = undefined,
        .preTransform = vk.api.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        .compositeAlpha = vk.api.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = vk_present_mode,
        .clipped = vk.api.VK_FALSE,
        .oldSwapchain = old_swapchain,
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

    return .{
        .swapchain = swapchain,
        .format = @enumFromInt(vk_format.format),
        .present_mode = @enumFromInt(vk_present_mode),
        .extent = .{
            .width = capabilities.currentExtent.width,
            .height = capabilities.currentExtent.height,
            .depth = 1,
        },
    };
}

pub const Descriptor = struct {
    surface: vk.Surface,
    format: vk.ImageFormat = .B8G8R8A8Unorm,
    present_mode: vk.PresentMode = .Fifo,
};

vk: vk.api.VkSwapchainKHR,
surface: vk.Surface,

device: vk.Device,

extent: vk.Extent3D,
format: vk.ImageFormat,
present_mode: vk.PresentMode,

images: []vk.api.VkImage,
views: []vk.ImageView,

pub fn init(device: vk.Device, desc: Descriptor) !Swapchain {
    // create the swapchain
    const result = try createSwapchain(
        device,
        desc.format,
        desc.present_mode,
        desc.surface.vk,
        null,
    );
    errdefer vk.api.vkDestroySwapchainKHR(device.vk, result.swapchain, null);

    // get the image count
    var images_count: u32 = 0;
    try vk.check(vk.api.vkGetSwapchainImagesKHR(
        device.vk,
        result.swapchain,
        &images_count,
        null,
    ));

    // allocate memory for the images
    const images = try device.allocator.alloc(vk.api.VkImage, images_count);
    errdefer device.allocator.free(images);

    // get the actual images
    try vk.check(vk.api.vkGetSwapchainImagesKHR(
        device.vk,
        result.swapchain,
        &images_count,
        images.ptr,
    ));

    // allocate memory for the image views and framebuffers
    const views = try device.allocator.alloc(vk.ImageView, images_count);
    errdefer device.allocator.free(views);

    // create the image views
    try createImageViews(device.vk, result.extent, result.format, images, views);

    return .{
        .vk = result.swapchain,
        .surface = desc.surface,

        .device = device,

        .format = result.format,
        .present_mode = result.present_mode,
        .extent = result.extent,

        .images = images,
        .views = views,
    };
}

pub fn deinit(self: Swapchain) void {
    for (self.views) |view| {
        view.deinit();
    }

    vk.api.vkDestroySwapchainKHR(self.device.vk, self.vk, null);

    // free memory
    self.device.allocator.free(self.images);
    self.device.allocator.free(self.views);
}

pub fn recreate(self: *Swapchain) !void {
    // create the new swapchain
    const result = try createSwapchain(
        self.device,
        self.format,
        self.present_mode,
        self.surface.vk,
        self.vk,
    );

    self.extent = result.extent;
    self.format = result.format;
    self.present_mode = result.present_mode;

    vk.api.vkDestroySwapchainKHR(self.device.vk, self.vk, null);
    self.vk = result.swapchain;

    // destroy the old swapchain

    // query the image count
    var images_count: u32 = 0;
    try vk.check(vk.api.vkGetSwapchainImagesKHR(self.device.vk, self.vk, &images_count, null));

    // re-allocate memory for the images
    self.images = try self.device.allocator.realloc(self.images, images_count);

    // get the actual images
    try vk.check(vk.api.vkGetSwapchainImagesKHR(self.device.vk, self.vk, &images_count, self.images.ptr));

    for (self.views) |*view| {
        view.deinit();
    }

    // re-allocate memory for the views and framebuffers
    self.views = try self.device.allocator.realloc(self.views, images_count);
    try createImageViews(self.device.vk, result.extent, result.format, self.images, self.views);
}

pub fn acquireNextImage(
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
