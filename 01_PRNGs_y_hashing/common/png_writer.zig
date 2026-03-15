const std = @import("std");

pub fn save_grayscale_png_uint8(filename: []const u8, image_data: []const u8, chunk_size: usize) !void {
    if (image_data.len != chunk_size * chunk_size) {
        return error.InvalidImageSize;
    }

    const width = std.math.cast(u32, chunk_size) orelse return error.DimensionTooLarge;
    const height = width;

    const allocator = std.heap.page_allocator;
    const stride = chunk_size + 1;
    const raw_len = try std.math.mul(usize, chunk_size, stride);
    const raw_scanlines = try allocator.alloc(u8, raw_len);
    defer allocator.free(raw_scanlines);

    for (0..chunk_size) |y| {
        const row_off = y * stride;
        raw_scanlines[row_off] = 0;
        @memcpy(
            raw_scanlines[row_off + 1 .. row_off + 1 + chunk_size],
            image_data[y * chunk_size .. (y + 1) * chunk_size],
        );
    }

    const zlib_data = try zlib_stored(allocator, raw_scanlines);
    defer allocator.free(zlib_data);

    var file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
    defer file.close();

    try file.writeAll(&[_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 });

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8;
    ihdr[9] = 0;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;

    try write_png_chunk(file, "IHDR", &ihdr);
    try write_png_chunk(file, "IDAT", zlib_data);
    try write_png_chunk(file, "IEND", "");
}

pub fn saveGrayscalePngUint8(filename: []const u8, image_data: []const u8, chunk_size: usize) !void {
    return save_grayscale_png_uint8(filename, image_data, chunk_size);
}

fn write_png_chunk(writer: anytype, chunk_type: []const u8, data: []const u8) !void {
    if (chunk_type.len != 4) return error.InvalidChunkType;

    const len_u32 = std.math.cast(u32, data.len) orelse return error.ChunkTooLarge;
    try write_be_u32(writer, len_u32);
    try writer.writeAll(chunk_type);
    try writer.writeAll(data);

    var crc = std.hash.Crc32.init();
    crc.update(chunk_type);
    crc.update(data);
    try write_be_u32(writer, crc.final());
}

fn write_be_u32(writer: anytype, value: u32) !void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, value, .big);
    try writer.writeAll(&buf);
}

fn adler32(data: []const u8) u32 {
    const mod: u32 = 65521;
    var a: u32 = 1;
    var b: u32 = 0;

    for (data) |byte| {
        a = (a + byte) % mod;
        b = (b + a) % mod;
    }

    return (b << 16) | a;
}

fn zlib_stored(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const blocks = @divFloor(data.len + 65534, 65535);
    const total_len = 2 + (blocks * 5) + data.len + 4;
    const out = try allocator.alloc(u8, total_len);

    var out_i: usize = 0;
    out[out_i] = 0x78;
    out_i += 1;
    out[out_i] = 0x01;
    out_i += 1;

    var offset: usize = 0;
    while (offset < data.len) {
        const remaining = data.len - offset;
        const block_len: u16 = @intCast(@min(remaining, 65535));
        const final_block: u8 = if (remaining <= 65535) 1 else 0;

        out[out_i] = final_block;
        out_i += 1;

        out[out_i] = @truncate(block_len & 0xff);
        out[out_i + 1] = @truncate(block_len >> 8);
        out_i += 2;

        const nlen: u16 = ~block_len;
        out[out_i] = @truncate(nlen & 0xff);
        out[out_i + 1] = @truncate(nlen >> 8);
        out_i += 2;

        @memcpy(out[out_i .. out_i + block_len], data[offset .. offset + block_len]);
        out_i += block_len;
        offset += block_len;
    }

    const adler = adler32(data);
    out[out_i] = @truncate((adler >> 24) & 0xff);
    out[out_i + 1] = @truncate((adler >> 16) & 0xff);
    out[out_i + 2] = @truncate((adler >> 8) & 0xff);
    out[out_i + 3] = @truncate(adler & 0xff);
    out_i += 4;

    std.debug.assert(out_i == total_len);
    return out;
}
