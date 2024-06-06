const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");

const event = @import("event.zig");
const math = @import("math.zig");

pub const glfw = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("GLFW/glfw3.h");
});

const Window = @This();

/// Error codes for the window module.
pub const Error = error{
    GlfwInit,
    GlfwCreateWindow,
    GlfwUninitialized,
    GlfwVulkanUnsupported,
};

var is_glfw_initialized = false;

fn glfwErrorCallback(
    err: i32,
    description: [*c]const u8,
) callconv(.C) void {
    std.debug.print("GLFW error {}: {s}\n", .{ err, description });
}

pub const Key = enum(u32) {
    A = glfw.GLFW_KEY_A,
    B = glfw.GLFW_KEY_B,
    C = glfw.GLFW_KEY_C,
    D = glfw.GLFW_KEY_D,
    E = glfw.GLFW_KEY_E,
    F = glfw.GLFW_KEY_F,
    G = glfw.GLFW_KEY_G,
    H = glfw.GLFW_KEY_H,
    I = glfw.GLFW_KEY_I,
    J = glfw.GLFW_KEY_J,
    K = glfw.GLFW_KEY_K,
    L = glfw.GLFW_KEY_L,
    M = glfw.GLFW_KEY_M,
    N = glfw.GLFW_KEY_N,
    O = glfw.GLFW_KEY_O,
    P = glfw.GLFW_KEY_P,
    Q = glfw.GLFW_KEY_Q,
    R = glfw.GLFW_KEY_R,
    S = glfw.GLFW_KEY_S,
    T = glfw.GLFW_KEY_T,
    U = glfw.GLFW_KEY_U,
    V = glfw.GLFW_KEY_V,
    W = glfw.GLFW_KEY_W,
    X = glfw.GLFW_KEY_X,
    Y = glfw.GLFW_KEY_Y,
    Z = glfw.GLFW_KEY_Z,

    Num0 = glfw.GLFW_KEY_0,
    Num1 = glfw.GLFW_KEY_1,
    Num2 = glfw.GLFW_KEY_2,
    Num3 = glfw.GLFW_KEY_3,
    Num4 = glfw.GLFW_KEY_4,
    Num5 = glfw.GLFW_KEY_5,
    Num6 = glfw.GLFW_KEY_6,
    Num7 = glfw.GLFW_KEY_7,
    Num8 = glfw.GLFW_KEY_8,
    Num9 = glfw.GLFW_KEY_9,

    Right = glfw.GLFW_KEY_RIGHT,
    Left = glfw.GLFW_KEY_LEFT,
    Up = glfw.GLFW_KEY_UP,
    Down = glfw.GLFW_KEY_DOWN,

    fn fromInt(int: c_int) ?Key {
        switch (int) {
            glfw.GLFW_KEY_A => return .A,
            glfw.GLFW_KEY_B => return .B,
            glfw.GLFW_KEY_C => return .C,
            glfw.GLFW_KEY_D => return .D,
            glfw.GLFW_KEY_E => return .E,
            glfw.GLFW_KEY_F => return .F,
            glfw.GLFW_KEY_G => return .G,
            glfw.GLFW_KEY_H => return .H,
            glfw.GLFW_KEY_I => return .I,
            glfw.GLFW_KEY_J => return .J,
            glfw.GLFW_KEY_K => return .K,
            glfw.GLFW_KEY_L => return .L,
            glfw.GLFW_KEY_M => return .M,
            glfw.GLFW_KEY_N => return .N,
            glfw.GLFW_KEY_O => return .O,
            glfw.GLFW_KEY_P => return .P,
            glfw.GLFW_KEY_Q => return .Q,
            glfw.GLFW_KEY_R => return .R,
            glfw.GLFW_KEY_S => return .S,
            glfw.GLFW_KEY_T => return .T,
            glfw.GLFW_KEY_U => return .U,
            glfw.GLFW_KEY_V => return .V,
            glfw.GLFW_KEY_W => return .W,
            glfw.GLFW_KEY_X => return .X,
            glfw.GLFW_KEY_Y => return .Y,
            glfw.GLFW_KEY_Z => return .Z,
            glfw.GLFW_KEY_0 => return .Num0,
            glfw.GLFW_KEY_1 => return .Num1,
            glfw.GLFW_KEY_2 => return .Num2,
            glfw.GLFW_KEY_3 => return .Num3,
            glfw.GLFW_KEY_4 => return .Num4,
            glfw.GLFW_KEY_5 => return .Num5,
            glfw.GLFW_KEY_6 => return .Num6,
            glfw.GLFW_KEY_7 => return .Num7,
            glfw.GLFW_KEY_8 => return .Num8,
            glfw.GLFW_KEY_9 => return .Num9,
            glfw.GLFW_KEY_RIGHT => return .Right,
            glfw.GLFW_KEY_LEFT => return .Left,
            glfw.GLFW_KEY_UP => return .Up,
            glfw.GLFW_KEY_DOWN => return .Down,
            else => return null,
        }
    }
};

pub const KeyInput = struct {
    key: ?Key,
    scan_code: u32,
    name: ?[]const u8,
    is_pressed: bool,
};

var glfw_keyboard_mutex: std.Thread.Mutex = std.Thread.Mutex{};
var glfw_keyboard_input: std.ArrayList(KeyInput) = undefined;

/// Initialize GLFW, this can be called multiple times, but will only initialize GLFW once.
pub fn initGlfw() !void {
    if (is_glfw_initialized) {
        return;
    }

    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);

    if (glfw.glfwInit() != glfw.GLFW_TRUE) {
        return Error.GlfwInit;
    }

    is_glfw_initialized = true;

    // initialize the keyboard input list
    glfw_keyboard_input = std.ArrayList(KeyInput).init(std.heap.page_allocator);
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

pub fn isKeyDown(window: Window, key: u32) bool {
    if (key < 128) {
        return glfw.glfwGetKey(window.window, std.ascii.toUpper(@truncate(key))) == glfw.GLFW_PRESS;
    }

    return glfw.glfwGetKey(window.window, @as(i32, @bitCast(key))) == glfw.GLFW_PRESS;
}

pub fn isMouseDown(window: Window, button: u8) bool {
    return glfw.glfwGetMouseButton(window.window, button) == glfw.GLFW_PRESS;
}

pub fn mousePosition(window: Window) math.Vec2 {
    var x: f64 = 0;
    var y: f64 = 0;
    glfw.glfwGetCursorPos(window.window, &x, &y);
    return math.vec2(@floatCast(x), @floatCast(y));
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
surface: vk.Surface,
instance: vk.Instance,

/// Create a new window, with the given descriptor.
pub fn init(desc: Descriptor) !Window {
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

    // set the key callback
    _ = glfw.glfwSetKeyCallback(window, glfwKeyCallback);

    // create the vulkan surface
    const surface = try createVkSurface(window, desc.instance.vk);

    return Window{
        .window = window,
        .surface = .{ .vk = surface, .instance = desc.instance.vk },
        .instance = desc.instance,
    };
}

fn glfwKeyCallback(
    window: ?*glfw.GLFWwindow,
    key_code: c_int,
    scan_code: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    _ = window;
    _ = mods;

    const c_name = glfw.glfwGetKeyName(key_code, 0);

    var name: ?[]const u8 = null;

    if (c_name != null) {
        name = std.mem.span(c_name);
    }

    const input = KeyInput{
        .key = Key.fromInt(key_code),
        .scan_code = @intCast(scan_code),
        .name = name,
        .is_pressed = action == glfw.GLFW_PRESS,
    };

    // lock the mutex and push the input
    glfw_keyboard_mutex.lock();
    glfw_keyboard_input.append(input) catch {};

    // unlock the mutex
    glfw_keyboard_mutex.unlock();
}

pub fn getKeyInput(self: *const Window, allocator: std.mem.Allocator) ![]const KeyInput {
    _ = self;

    // lock the mutex
    glfw_keyboard_mutex.lock();

    // copy the input
    const input = try allocator.dupe(KeyInput, glfw_keyboard_input.items);

    // clear the input
    glfw_keyboard_input.clearRetainingCapacity();

    // unlock the mutex
    glfw_keyboard_mutex.unlock();

    return input;
}

pub fn shouldClose(self: *const Window) bool {
    return glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_TRUE;
}

pub fn setTitle(self: *const Window, title: []const u8) void {
    glfw.glfwSetWindowTitle(self.window, title.ptr);
}

pub fn getSize(self: *const Window) vk.Extent2D {
    var width: i32 = 0;
    var height: i32 = 0;
    glfw.glfwGetWindowSize(self.window, &width, &height);
    return .{
        .width = @intCast(width),
        .height = @intCast(height),
    };
}

pub fn getMousePosition(self: *const Window) math.Vec2 {
    var x: f64 = 0;
    var y: f64 = 0;
    glfw.glfwGetCursorPos(self.window, &x, &y);
    return math.vec2(@floatCast(x), @floatCast(y));
}

pub fn cursorNormal(self: *const Window) void {
    if (glfw.glfwGetInputMode(self.window, glfw.GLFW_CURSOR) != glfw.GLFW_CURSOR_NORMAL)
        glfw.glfwSetInputMode(self.window, glfw.GLFW_CURSOR, glfw.GLFW_CURSOR_NORMAL);
}

pub fn cursorHidden(self: *const Window) void {
    if (glfw.glfwGetInputMode(self.window, glfw.GLFW_CURSOR) != glfw.GLFW_CURSOR_HIDDEN)
        glfw.glfwSetInputMode(self.window, glfw.GLFW_CURSOR, glfw.GLFW_CURSOR_HIDDEN);
}

pub fn cursorDisabled(self: *const Window) void {
    if (glfw.glfwGetInputMode(self.window, glfw.GLFW_CURSOR) != glfw.GLFW_CURSOR_DISABLED)
        glfw.glfwSetInputMode(self.window, glfw.GLFW_CURSOR, glfw.GLFW_CURSOR_DISABLED);
}

pub fn deinit(self: *const Window) void {
    // destroy the surface first
    self.surface.deinit();
    glfw.glfwDestroyWindow(self.window);
}

pub const SizeChanged = struct {
    size: vk.Extent2D,
};

pub const MouseMoved = struct {
    position: math.Vec2,
    delta: math.Vec2,
};

pub const State = struct {
    window_size: vk.Extent2D = .{ .width = 0, .height = 0 },
    mouse_position: math.Vec2 = math.Vec2.ZERO,
};

pub fn eventSystem(
    allocator: std.mem.Allocator,
    size_changed: event.EventWriter(SizeChanged),
    mouse_moved: event.EventWriter(MouseMoved),
    key_input: event.EventWriter(KeyInput),
    window: *Window,
    state: *State,
) !void {
    const new_size = window.getSize();
    const new_position = window.getMousePosition();

    if (!state.mouse_position.eql(new_position)) {
        const delta = new_position.sub(state.mouse_position);
        state.mouse_position = new_position;

        try mouse_moved.send(.{
            .position = new_position,
            .delta = delta,
        });
    }

    if (state.window_size.width != new_size.width or
        state.window_size.height != new_size.height)
    {
        state.window_size = new_size;
        try size_changed.send(.{
            .size = state.window_size,
        });
    }

    const input = try window.getKeyInput(allocator);

    for (input) |key| {
        try key_input.send(key);
    }

    allocator.free(input);
}
