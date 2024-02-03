/// The Vulkan C API.
pub const api = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const BindGroup = @import("BindGroup.zig");
pub const BindGroupLayout = @import("BindGroupLayout.zig");
pub const BindGroupPool = @import("BindGroupPool.zig");
pub const Buffer = @import("Buffer.zig");
pub const CommandBuffer = @import("CommandBuffer.zig");
pub const CommandPool = @import("CommandPool.zig");
pub const Device = @import("Device.zig");
pub const Fence = @import("Fence.zig");
pub const Framebuffer = @import("Framebuffer.zig");
pub const GraphicsPipeline = @import("GraphicsPipeline.zig");
pub const Image = @import("Image.zig");
pub const ImageView = @import("ImageView.zig");
pub const Instance = @import("Instance.zig");
pub const Queue = @import("Queue.zig");
pub const RenderPass = @import("RenderPass.zig");
pub const Semaphore = @import("Semaphore.zig");
pub const StagingBuffer = @import("StagingBuffer.zig");
pub const Swapchain = @import("Swapchain.zig");

pub const Attachment = RenderPass.Attachment;
pub const Subpass = RenderPass.Subpass;
pub const AttachmentReference = RenderPass.AttachmentReference;

pub const Spv = []const u32;

const std = @import("std");

/// Embed a SPIR-V file as a `[]const u32`.
pub fn embedSpv(comptime path: []const u8) Spv {
    // we need to do this whole rigmarole to ensure correct alignment
    // I do not like it, but it is what it is

    const data = @embedFile(path);
    const len = data.len / @sizeOf(u32);

    if (data.len % @sizeOf(u32) != 0) {
        @compileError("SPIR-V file size is not a multiple of 4");
    }

    // this is beyond stupid, but it's the only way to do it
    comptime var spv: [len]u32 = undefined;
    @memcpy(@as([*]u8, @ptrCast(&spv)), data);

    return &spv;
}

pub fn vkBool(b: bool) api.VkBool32 {
    return if (b) api.VK_TRUE else api.VK_FALSE;
}

pub const SUBPASS_EXTERNAL: u32 = api.VK_SUBPASS_EXTERNAL;

pub const ShaderStages = packed struct {
    vertex: bool = false,
    tessellation_control: bool = false,
    tessellation_evaluation: bool = false,
    geometry: bool = false,
    fragment: bool = false,
    compute: bool = false,

    _unused: u2 = 0,

    comptime {
        std.debug.assert(@sizeOf(ShaderStages) == @sizeOf(u8));
    }

    pub fn asBits(self: ShaderStages) u8 {
        return @bitCast(self);
    }
};

pub const PipelineStages = packed struct {
    top_of_pipe: bool = false,
    draw_indirect: bool = false,
    vertex_input: bool = false,
    vertex_shader: bool = false,
    tessellation_control_shader: bool = false,
    tessellation_evaluation_shader: bool = false,
    geometry_shader: bool = false,
    fragment_shader: bool = false,
    early_fragment_tests: bool = false,
    late_fragment_tests: bool = false,
    color_attachment_output: bool = false,
    compute_shader: bool = false,
    transfer: bool = false,
    bottom_of_pipe: bool = false,
    host: bool = false,
    all_graphics: bool = false,
    all_commands: bool = false,

    _unused: u15 = 0,

    comptime {
        std.debug.assert(@sizeOf(PipelineStages) == @sizeOf(u32));
    }

    pub fn asBits(self: PipelineStages) u32 {
        return @bitCast(self);
    }
};

pub const Access = packed struct {
    indirect_command_read: bool = false,
    index_read: bool = false,
    vertex_attribute_read: bool = false,
    uniform_read: bool = false,
    input_attachment_read: bool = false,
    shader_read: bool = false,
    shader_write: bool = false,
    color_attachment_read: bool = false,
    color_attachment_write: bool = false,
    depth_stencil_attachment_read: bool = false,
    depth_stencil_attachment_write: bool = false,
    transfer_read: bool = false,
    transfer_write: bool = false,
    host_read: bool = false,
    host_write: bool = false,
    memory_read: bool = false,
    memory_write: bool = false,

    _unused: u15 = 0,

    comptime {
        std.debug.assert(@sizeOf(Access) == @sizeOf(u32));
    }

    pub fn asBits(self: Access) u32 {
        return @bitCast(self);
    }
};

pub const MemoryProperties = packed struct {
    device_local: bool = false,
    host_visible: bool = false,
    host_coherent: bool = false,
    host_cached: bool = false,
    lazily_allocated: bool = false,
    protected: bool = false,
    device_coherent: bool = false,
    device_uncached: bool = false,
    device_protected: bool = false,

    _unused: u23 = 0,

    comptime {
        std.debug.assert(@sizeOf(MemoryProperties) == @sizeOf(u32));
    }

    pub fn asBits(self: MemoryProperties) u32 {
        return @bitCast(self);
    }
};

pub const IndexType = enum {
    u16,
    u32,

    pub fn asVk(self: IndexType) api.VkIndexType {
        return switch (self) {
            IndexType.u16 => api.VK_INDEX_TYPE_UINT16,
            IndexType.u32 => api.VK_INDEX_TYPE_UINT32,
        };
    }
};

/// A Vulkan error, derived from `VkResult`.
pub const Error = error{
    UNKNOWN,
    VK_NOT_READY,
    VK_TIMEOUT,
    VK_EVENT_SET,
    VK_EVENT_RESET,
    VK_INCOMPLETE,
    VK_ERROR_OUT_OF_HOST_MEMORY,
    VK_ERROR_OUT_OF_DEVICE_MEMORY,
    VK_ERROR_INITIALIZATION_FAILED,
    VK_ERROR_DEVICE_LOST,
    VK_ERROR_MEMORY_MAP_FAILED,
    VK_ERROR_LAYER_NOT_PRESENT,
    VK_ERROR_EXTENSION_NOT_PRESENT,
    VK_ERROR_FEATURE_NOT_PRESENT,
    VK_ERROR_INCOMPATIBLE_DRIVER,
    VK_ERROR_TOO_MANY_OBJECTS,
    VK_ERROR_FORMAT_NOT_SUPPORTED,
    VK_ERROR_FRAGMENTED_POOL,
    VK_ERROR_UNKNOWN,
    // Provided by VK_VERSION_1_1
    VK_ERROR_OUT_OF_POOL_MEMORY,
    // Provided by VK_VERSION_1_1
    VK_ERROR_INVALID_EXTERNAL_HANDLE,
    // Provided by VK_VERSION_1_2
    VK_ERROR_FRAGMENTATION,
    // Provided by VK_VERSION_1_2
    VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS,
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_COMPILE_REQUIRED,
    // Provided by VK_KHR_surface
    VK_ERROR_SURFACE_LOST_KHR,
    // Provided by VK_KHR_surface
    VK_ERROR_NATIVE_WINDOW_IN_USE_KHR,
    // Provided by VK_KHR_swapchain
    VK_SUBOPTIMAL_KHR,
    // Provided by VK_KHR_swapchain
    VK_ERROR_OUT_OF_DATE_KHR,
    // Provided by VK_KHR_display_swapchain
    VK_ERROR_INCOMPATIBLE_DISPLAY_KHR,
    // Provided by VK_EXT_debug_report
    VK_ERROR_VALIDATION_FAILED_EXT,
    // Provided by VK_NV_glsl_shader
    VK_ERROR_INVALID_SHADER_NV,
    // Provided by VK_KHR_video_queue
    VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR,
    // Provided by VK_KHR_video_queue
    VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR,
    // Provided by VK_KHR_video_queue
    VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR,
    // Provided by VK_KHR_video_queue
    VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR,
    // Provided by VK_KHR_video_queue
    VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR,
    // Provided by VK_KHR_video_queue
    VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR,
    // Provided by VK_EXT_image_drm_format_modifier
    VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT,
    // Provided by VK_KHR_global_priority
    VK_ERROR_NOT_PERMITTED_KHR,
    // Provided by VK_EXT_full_screen_exclusive
    VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT,
    // Provided by VK_KHR_deferred_host_operations
    VK_THREAD_IDLE_KHR,
    // Provided by VK_KHR_deferred_host_operations
    VK_THREAD_DONE_KHR,
    // Provided by VK_KHR_deferred_host_operations
    VK_OPERATION_DEFERRED_KHR,
    // Provided by VK_KHR_deferred_host_operations
    VK_OPERATION_NOT_DEFERRED_KHR,
    // Provided by VK_KHR_video_encode_queue
    VK_ERROR_INVALID_VIDEO_STD_PARAMETERS_KHR,
    // Provided by VK_EXT_image_compression_control
    VK_ERROR_COMPRESSION_EXHAUSTED_EXT,
    // Provided by VK_EXT_shader_object
    VK_ERROR_INCOMPATIBLE_SHADER_BINARY_EXT,
    // Provided by VK_KHR_maintenance1
    VK_ERROR_OUT_OF_POOL_MEMORY_KHR,
    // Provided by VK_KHR_external_memory
    VK_ERROR_INVALID_EXTERNAL_HANDLE_KHR,
    // Provided by VK_EXT_descriptor_indexing
    VK_ERROR_FRAGMENTATION_EXT,
    // Provided by VK_EXT_global_priority
    VK_ERROR_NOT_PERMITTED_EXT,
    // Provided by VK_EXT_buffer_device_address
    VK_ERROR_INVALID_DEVICE_ADDRESS_EXT,
    // Provided by VK_KHR_buffer_device_address
    VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS_KHR,
    // Provided by VK_EXT_pipeline_creation_cache_control
    VK_PIPELINE_COMPILE_REQUIRED_EXT,
    // Provided by VK_EXT_pipeline_creation_cache_control
    VK_ERROR_PIPELINE_COMPILE_REQUIRED_EXT,
};

/// Check if a `VkResult` is a success, and if not, return the corresponding error.
pub fn check(result: api.VkResult) !void {
    if (result == api.VK_SUCCESS) return;

    return switch (result) {
        api.VK_NOT_READY => Error.VK_NOT_READY,
        api.VK_TIMEOUT => Error.VK_TIMEOUT,
        api.VK_EVENT_SET => Error.VK_EVENT_SET,
        api.VK_EVENT_RESET => Error.VK_EVENT_RESET,
        api.VK_INCOMPLETE => Error.VK_INCOMPLETE,
        api.VK_ERROR_OUT_OF_HOST_MEMORY => Error.VK_ERROR_OUT_OF_HOST_MEMORY,
        api.VK_ERROR_OUT_OF_DEVICE_MEMORY => Error.VK_ERROR_OUT_OF_DEVICE_MEMORY,
        api.VK_ERROR_INITIALIZATION_FAILED => Error.VK_ERROR_INITIALIZATION_FAILED,
        api.VK_ERROR_DEVICE_LOST => Error.VK_ERROR_DEVICE_LOST,
        api.VK_ERROR_MEMORY_MAP_FAILED => Error.VK_ERROR_MEMORY_MAP_FAILED,
        api.VK_ERROR_LAYER_NOT_PRESENT => Error.VK_ERROR_LAYER_NOT_PRESENT,
        api.VK_ERROR_EXTENSION_NOT_PRESENT => Error.VK_ERROR_EXTENSION_NOT_PRESENT,
        api.VK_ERROR_FEATURE_NOT_PRESENT => Error.VK_ERROR_FEATURE_NOT_PRESENT,
        api.VK_ERROR_INCOMPATIBLE_DRIVER => Error.VK_ERROR_INCOMPATIBLE_DRIVER,
        api.VK_ERROR_TOO_MANY_OBJECTS => Error.VK_ERROR_TOO_MANY_OBJECTS,
        api.VK_ERROR_FORMAT_NOT_SUPPORTED => Error.VK_ERROR_FORMAT_NOT_SUPPORTED,
        api.VK_ERROR_FRAGMENTED_POOL => Error.VK_ERROR_FRAGMENTED_POOL,
        api.VK_ERROR_UNKNOWN => Error.VK_ERROR_UNKNOWN,
        api.VK_ERROR_OUT_OF_POOL_MEMORY => Error.VK_ERROR_OUT_OF_POOL_MEMORY,
        api.VK_ERROR_INVALID_EXTERNAL_HANDLE => Error.VK_ERROR_INVALID_EXTERNAL_HANDLE,
        api.VK_ERROR_FRAGMENTATION => Error.VK_ERROR_FRAGMENTATION,
        api.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS => Error.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS,
        api.VK_PIPELINE_COMPILE_REQUIRED => Error.VK_PIPELINE_COMPILE_REQUIRED,
        api.VK_ERROR_SURFACE_LOST_KHR => Error.VK_ERROR_SURFACE_LOST_KHR,
        api.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR => Error.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR,
        api.VK_SUBOPTIMAL_KHR => Error.VK_SUBOPTIMAL_KHR,
        api.VK_ERROR_OUT_OF_DATE_KHR => Error.VK_ERROR_OUT_OF_DATE_KHR,
        api.VK_ERROR_INCOMPATIBLE_DISPLAY_KHR => Error.VK_ERROR_INCOMPATIBLE_DISPLAY_KHR,
        api.VK_ERROR_VALIDATION_FAILED_EXT => Error.VK_ERROR_VALIDATION_FAILED_EXT,
        api.VK_ERROR_INVALID_SHADER_NV => Error.VK_ERROR_INVALID_SHADER_NV,
        api.VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR => Error.VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR,
        api.VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR => Error.VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR,
        api.VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR => Error.VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR,
        api.VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR => Error.VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR,
        api.VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR => Error.VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR,
        api.VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR => Error.VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR,
        api.VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT => Error.VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT,
        api.VK_ERROR_NOT_PERMITTED_KHR => Error.VK_ERROR_NOT_PERMITTED_KHR,
        api.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT => Error.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT,
        api.VK_THREAD_IDLE_KHR => Error.VK_THREAD_IDLE_KHR,
        api.VK_THREAD_DONE_KHR => Error.VK_THREAD_DONE_KHR,
        api.VK_OPERATION_DEFERRED_KHR => Error.VK_OPERATION_DEFERRED_KHR,
        api.VK_OPERATION_NOT_DEFERRED_KHR => Error.VK_OPERATION_NOT_DEFERRED_KHR,
        else => Error.UNKNOWN,
    };
}
