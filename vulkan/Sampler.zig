const std = @import("std");
const vk = @import("vk.zig");

const Sampler = @This();

pub const Descriptor = struct {
    min_filter: vk.Filter = .Nearest,
    mag_filter: vk.Filter = .Nearest,
    mipmap_mode: vk.MipmapMode = .Nearest,
    address_mode_u: vk.AddressMode = .ClampToEdge,
    address_mode_v: vk.AddressMode = .ClampToEdge,
    address_mode_w: vk.AddressMode = .ClampToEdge,
    mip_lod_bias: f32 = 0.0,
    max_anisotropy: ?f32 = null,
    compare_op: ?vk.CompareOp = .Never,
    min_lod: f32 = 0.0,
    max_lod: f32 = 0.0,
    border_color: vk.BorderColor = .FloatTransparentBlack,
    unnormalized_coordinates: bool = false,
};

vk: vk.api.VkSampler,
device: vk.api.VkDevice,

pub fn init(device: vk.Device, desc: Descriptor) !Sampler {
    const sampler_info = vk.api.VkSamplerCreateInfo{
        .sType = vk.api.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .magFilter = @intFromEnum(desc.mag_filter),
        .minFilter = @intFromEnum(desc.min_filter),
        .mipmapMode = @intFromEnum(desc.mipmap_mode),
        .addressModeU = @intFromEnum(desc.address_mode_u),
        .addressModeV = @intFromEnum(desc.address_mode_v),
        .addressModeW = @intFromEnum(desc.address_mode_w),
        .mipLodBias = desc.mip_lod_bias,
        .anisotropyEnable = vk.vkBool(desc.max_anisotropy != null),
        .maxAnisotropy = desc.max_anisotropy orelse 0.0,
        .compareEnable = vk.vkBool(desc.compare_op != null),
        .compareOp = @intFromEnum(desc.compare_op orelse .Never),
        .minLod = desc.min_lod,
        .maxLod = desc.max_lod,
        .borderColor = @intFromEnum(desc.border_color),
        .unnormalizedCoordinates = vk.vkBool(desc.unnormalized_coordinates),
    };

    var sampler: vk.api.VkSampler = undefined;
    try vk.check(vk.api.vkCreateSampler(device.vk, &sampler_info, null, &sampler));

    return .{
        .vk = sampler,
        .device = device.vk,
    };
}

pub fn deinit(self: Sampler) void {
    vk.api.vkDestroySampler(self.device, self.vk, null);
}
