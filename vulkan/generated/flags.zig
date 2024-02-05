// Bitmask for VK_ACCESS_
pub const Access = packed struct(u32) {
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

    pub const ALL: Access = .{
        .indirect_command_read = true,
        .index_read = true,
        .vertex_attribute_read = true,
        .uniform_read = true,
        .input_attachment_read = true,
        .shader_read = true,
        .shader_write = true,
        .color_attachment_read = true,
        .color_attachment_write = true,
        .depth_stencil_attachment_read = true,
        .depth_stencil_attachment_write = true,
        .transfer_read = true,
        .transfer_write = true,
        .host_read = true,
        .host_write = true,
        .memory_read = true,
        .memory_write = true,
    };
};

// Bitmask for VK_BUFFER_USAGE_
pub const BufferUsages = packed struct(u32) {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    uniform_texel_buffer: bool = false,
    storage_texel_buffer: bool = false,
    uniform_buffer: bool = false,
    storage_buffer: bool = false,
    index_buffer: bool = false,
    vertex_buffer: bool = false,
    indirect_buffer: bool = false,
    _9: bool = false,
    _10: bool = false,
    _11: bool = false,
    _12: bool = false,
    _13: bool = false,
    _14: bool = false,
    _15: bool = false,
    _16: bool = false,
    shader_device_address: bool = false,
    _unused: u14 = 0,

    pub const ALL: BufferUsages = .{
        .transfer_src = true,
        .transfer_dst = true,
        .uniform_texel_buffer = true,
        .storage_texel_buffer = true,
        .uniform_buffer = true,
        .storage_buffer = true,
        .index_buffer = true,
        .vertex_buffer = true,
        .indirect_buffer = true,
        .shader_device_address = true,
    };
};

// Bitmask for VK_CULL_MODE_
pub const CullModes = packed struct(u32) {
    front: bool = false,
    back: bool = false,
    _unused: u30 = 0,

    pub const ALL: CullModes = .{
        .front = true,
        .back = true,
    };
};

// Bitmask for VK_COLOR_COMPONENT_
pub const ColorComponents = packed struct(u32) {
    r: bool = false,
    g: bool = false,
    b: bool = false,
    a: bool = false,
    _unused: u28 = 0,

    pub const ALL: ColorComponents = .{
        .r = true,
        .g = true,
        .b = true,
        .a = true,
    };
};

// Bitmask for VK_DEPENDENCY_
pub const Dependencies = packed struct(u32) {
    by_region: bool = false,
    view_local: bool = false,
    device_group: bool = false,
    _unused: u29 = 0,

    pub const ALL: Dependencies = .{
        .by_region = true,
        .view_local = true,
        .device_group = true,
    };
};

// Bitmask for VK_IMAGE_ASPECT_
pub const ImageAspects = packed struct(u32) {
    color: bool = false,
    depth: bool = false,
    stencil: bool = false,
    metadata: bool = false,
    plane_0: bool = false,
    plane_1: bool = false,
    plane_2: bool = false,
    _unused: u25 = 0,

    pub const ALL: ImageAspects = .{
        .color = true,
        .depth = true,
        .stencil = true,
        .metadata = true,
        .plane_0 = true,
        .plane_1 = true,
        .plane_2 = true,
    };
};

// Bitmask for VK_IMAGE_USAGE_
pub const ImageUsages = packed struct(u32) {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    sampled: bool = false,
    storage: bool = false,
    color_attachment: bool = false,
    depth_stencil_attachment: bool = false,
    transient_attachment: bool = false,
    input_attachment: bool = false,
    _unused: u24 = 0,

    pub const ALL: ImageUsages = .{
        .transfer_src = true,
        .transfer_dst = true,
        .sampled = true,
        .storage = true,
        .color_attachment = true,
        .depth_stencil_attachment = true,
        .transient_attachment = true,
        .input_attachment = true,
    };
};

// Bitmask for VK_MEMORY_PROPERTY_
pub const MemoryProperties = packed struct(u32) {
    device_local: bool = false,
    host_visible: bool = false,
    host_coherent: bool = false,
    host_cached: bool = false,
    lazily_allocated: bool = false,
    protected: bool = false,
    _unused: u26 = 0,

    pub const ALL: MemoryProperties = .{
        .device_local = true,
        .host_visible = true,
        .host_coherent = true,
        .host_cached = true,
        .lazily_allocated = true,
        .protected = true,
    };
};

// Bitmask for VK_PIPELINE_STAGE_
pub const PipelineStages = packed struct(u32) {
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

    pub const ALL: PipelineStages = .{
        .top_of_pipe = true,
        .draw_indirect = true,
        .vertex_input = true,
        .vertex_shader = true,
        .tessellation_control_shader = true,
        .tessellation_evaluation_shader = true,
        .geometry_shader = true,
        .fragment_shader = true,
        .early_fragment_tests = true,
        .late_fragment_tests = true,
        .color_attachment_output = true,
        .compute_shader = true,
        .transfer = true,
        .bottom_of_pipe = true,
        .host = true,
        .all_graphics = true,
        .all_commands = true,
    };
};

// Bitmask for VK_SHADER_STAGE_
pub const ShaderStages = packed struct(u32) {
    vertex: bool = false,
    tessellation_control: bool = false,
    tessellation_evaluation: bool = false,
    geometry: bool = false,
    fragment: bool = false,
    compute: bool = false,
    _unused: u26 = 0,

    pub const ALL: ShaderStages = .{
        .vertex = true,
        .tessellation_control = true,
        .tessellation_evaluation = true,
        .geometry = true,
        .fragment = true,
        .compute = true,
    };
};

