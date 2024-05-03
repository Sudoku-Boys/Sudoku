const std = @import("std");

const Image = @This();

pub const PIXEL_SIZE = 4;

pub const Format = enum {
    Srgb,
    Linear,
};

pub const Filter = enum {
    Nearest,
    Linear,
};

allocator: std.mem.Allocator,
data: []u8,
width: u32,
height: u32,
format: Format = .Srgb,
filter: Filter = .Nearest,

pub fn init(
    allocator: std.mem.Allocator,
    data: []const u8,
    width: u32,
    height: u32,
) !Image {
    return .{
        .allocator = allocator,
        .data = try allocator.dupe(data),
        .width = width,
        .height = height,
    };
}

pub fn deinit(self: *Image) void {
    self.allocator.free(self.data);
}

pub fn load_qoi(
    allocator: std.mem.Allocator,
    path: []const u8,
) !Image {
    const file = try std.fs.cwd().openFile(path, .{});
    const reader = file.reader().any();

    return read_qoi(allocator, reader);
}

pub fn read_qoi(
    allocator: std.mem.Allocator,
    reader: std.io.AnyReader,
) !Image {
    const Error = error{
        InvalidMagic,
        InvalidFormat,
    };

    const Header = extern struct {
        magic: u32,
        width: u32,
        height: u32,
    };

    const header: Header = try reader.readStructEndian(Header, .big);

    const channels = try reader.readByte();
    const colorspace = try reader.readByte();
    _ = channels;

    // check that the magic is correct
    if (header.magic != 0x716f6966) {
        return Error.InvalidMagic;
    }

    const format = switch (colorspace) {
        0 => Format.Srgb,
        1 => Format.Linear,
        else => return Error.InvalidFormat,
    };

    const data = try allocator.alloc(u8, header.width * header.height * PIXEL_SIZE);
    var index: usize = 0;

    var seen: [64][4]u8 = .{.{ 0, 0, 0, 0 }} ** 64;

    var r: u8 = 0;
    var g: u8 = 0;
    var b: u8 = 0;
    var a: u8 = 255;

    var run: u8 = 0;

    while (true) {
        if (run == 0) {
            const tag = try reader.readByte();

            const two_bits = tag & 0b1100_0000;
            const six_bits = tag & 0b0011_1111;

            if (tag == 0b1111_1110) {
                r = try reader.readByte();
                g = try reader.readByte();
                b = try reader.readByte();
            } else if (tag == 0b1111_1111) {
                r = try reader.readByte();
                g = try reader.readByte();
                b = try reader.readByte();
                a = try reader.readByte();
            } else if (two_bits == 0b0000_0000) {
                const pixel = seen[six_bits];

                r = pixel[0];
                g = pixel[1];
                b = pixel[2];
                a = pixel[3];
            } else if (two_bits == 0b0100_0000) {
                const dr = ((six_bits >> 4) & 0b11) -% 2;
                const dg = ((six_bits >> 2) & 0b11) -% 2;
                const db = ((six_bits >> 0) & 0b11) -% 2;

                r +%= dr;
                g +%= dg;
                b +%= db;
            } else if (two_bits == 0b1000_0000) {
                const dg = six_bits -% 32;

                const drdb = try reader.readByte();

                const dr = ((drdb >> 4) & 0b1111) -% 8;
                const db = ((drdb >> 0) & 0b1111) -% 8;

                r +%= dg +% dr;
                g +%= dg;
                b +%= dg +% db;
            } else if (two_bits == 0b1100_0000) {
                run = six_bits;
            }
        } else {
            run -= 1;
        }

        data[index + 0] = r;
        data[index + 1] = g;
        data[index + 2] = b;
        data[index + 3] = a;
        index += PIXEL_SIZE;

        const hash = qoi_hash(r, g, b, a);
        seen[hash] = .{ r, g, b, a };

        if (index >= data.len) {
            break;
        }
    }

    return .{
        .allocator = allocator,
        .data = data,
        .width = header.width,
        .height = header.height,
        .format = format,
        .filter = Filter.Linear,
    };
}

fn qoi_hash(r: u8, g: u8, b: u8, a: u8) u8 {
    return (r *% 3 +% g *% 5 +% b *% 7 +% a *% 11) % 64;
}
