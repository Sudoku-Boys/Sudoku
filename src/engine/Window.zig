const builtin = @import("builtin");
pub const vk = @import("../vulkan/vk.zig");

pub const glfw = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("GLFW/glfw3.h");
});

const Self = @This();

/// Error codes for the window module.
pub const Error = error{
    GlfwInit,
    GlfwCreateWindow,
    GlfwUninitialized,
    GlfwVulkanUnsupported,
};

var is_glfw_initialized = false;

/// Initialize GLFW, this can be called multiple times, but will only initialize GLFW once.
pub fn initGlfw() !void {
    if (is_glfw_initialized) {
        return;
    }

    if (glfw.glfwInit() != glfw.GLFW_TRUE) {
        return Error.GlfwInit;
    }

    is_glfw_initialized = true;
}

/// Deinitialize GLFW, this can be called multiple times, but will only deinitialize GLFW once.
pub fn deinitGlfw() void {
    if (is_glfw_initialized) {
        glfw.glfwTerminate();
        is_glfw_initialized = false;
    }
}

/// Assert that GLFW is initialized, if not returns `GlfwUninitialized`.
pub fn assertGlfwInitialized() !void {
    if (builtin.mode != .Debug) {
        return;
    }

    if (!is_glfw_initialized) {
        return Error.GlfwUninitialized;
    }
}

/// Block until an event occurs, or the timeout is reached.
pub fn pollEvents() void {
    glfw.glfwPollEvents();
}

/// Get the required Vulkan extensions for GLFW.
pub fn requiredVulkanExtensions() []const [*c]const u8 {
    var count: u32 = 0;
    const extensions = glfw.glfwGetRequiredInstanceExtensions(&count);
    return @constCast(extensions[0..count]);
}

fn createVkSurface(window: *glfw.GLFWwindow, instance: vk.api.VkInstance) !vk.api.VkSurfaceKHR {
    var surface: vk.api.VkSurfaceKHR = undefined;

    const result = glfw.glfwCreateWindowSurface(
        @ptrCast(instance),
        window,
        null,
        @ptrCast(&surface),
    );

    try vk.check(result);

    return surface;
}

fn destroyVkSurface(surface: vk.api.VkSurfaceKHR, instance: vk.api.VkInstance) void {
    vk.api.vkDestroySurfaceKHR(
        @ptrCast(instance),
        @ptrCast(surface),
        null,
    );
}

/// The window descriptor.
pub const Descriptor = struct {
    /// The width of the window.
    width: u32 = 640,
    /// The height of the window.
    height: u32 = 480,
    /// The title of the window.
    title: []const u8 = "Sudoku engine",
    /// The Vulkan instance to create the surface for.
    instance: vk.Instance,
};

window: *glfw.GLFWwindow,
surface: vk.api.VkSurfaceKHR,
instance: vk.Instance,

/// Create a new window, with the given descriptor.
pub fn init(desc: Descriptor) !Self {
    try assertGlfwInitialized();

    // check if Vulkan is supported, if not what even is the point
    if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
        return Error.GlfwVulkanUnsupported;
    }

    // we don't need OpenGL, so we can disable it
    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);

    // create the window
    const window = glfw.glfwCreateWindow(
        @intCast(desc.width),
        @intCast(desc.height),
        desc.title.ptr,
        null,
        null,
    ) orelse return Error.GlfwCreateWindow;

    // create the vulkan surface
    const surface = try createVkSurface(window, desc.instance.vk);

    return Self{
        .window = window,
        .surface = surface,
        .instance = desc.instance,
    };
}

pub fn shouldClose(self: *const Self) bool {
    return glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_TRUE;
}

pub fn deinit(self: *const Self) void {
    // destroy the surface first
    destroyVkSurface(self.surface, self.instance.vk);
    glfw.glfwDestroyWindow(self.window);
}
