const std = @import("std");
const zigimg = @import("zigimg");
const scratch = @import("../scratch.zig");

inline fn sample_to_gray8(sample: i16) u8 {
    const scaled: f32 = ((@as(f32, @floatFromInt(sample)) / 32767.0) + 1.0) * 127.5;
    return @intFromFloat(@min(@max(scaled, 0.0), 255.0));
}

pub fn write_composite_image(
    comptime mod: type,
    perlin_cfg: anytype,
    chunk_buffer: []i16,
    gc_buffer: anytype,
    allocator: std.mem.Allocator,
    mode_str: []const u8,
    save_chunks_per_side: u64,
) !void {
    const scratch_bytes = comptime scratch.bytes_for_mod(mod);
    const scratch_align = comptime scratch.alignment_for_mod(mod);
    var scratch_buffer: [scratch_bytes]u8 align(scratch_align) = undefined;

    const cs_usize: usize = @intCast(perlin_cfg.chunk_size);
    const chunks_per_side_usize: usize = @intCast(save_chunks_per_side);

    const width: usize = cs_usize * chunks_per_side_usize;
    const height: usize = cs_usize * chunks_per_side_usize;
    const img_bytes = try allocator.alloc(u8, width * height);
    defer allocator.free(img_bytes);

    const save_chunks_i64: i64 = @intCast(save_chunks_per_side);
    const half: i64 = @divFloor(save_chunks_i64, 2);

    const min_idx: i64 = -half;
    const max_idx: i64 = save_chunks_i64 - half;

    var y_idx: i64 = min_idx;
    while (y_idx < max_idx) : (y_idx += 1) {
        var x_idx: i64 = min_idx;
        while (x_idx < max_idx) : (x_idx += 1) {
            const eval_y = save_chunks_i64 - 1 - y_idx;

            var fba = std.heap.FixedBufferAllocator.init(&scratch_buffer);
            const scratch_allocator = fba.allocator();

            mod.perlin_generate_chunk2d(perlin_cfg, x_idx, eval_y, chunk_buffer, gc_buffer, scratch_allocator);

            for (0..cs_usize) |row| {
                const grid_y: usize = @intCast(y_idx - min_idx);
                const global_y = grid_y * cs_usize + row;

                for (0..cs_usize) |col| {
                    const grid_x: usize = @intCast(x_idx - min_idx);
                    const global_x = grid_x * cs_usize + col;

                    const sample = chunk_buffer[row * cs_usize + col];
                    img_bytes[global_y * width + global_x] = sample_to_gray8(sample);
                }
            }
        }
    }

    var img = try zigimg.Image.fromRawPixelsOwned(width, height, img_bytes, .grayscale8);
    defer img.deinit(allocator);

    try std.fs.cwd().makePath("output");
    const write_buf: []u8 = try allocator.alloc(u8, (width * height) + 1024);
    defer allocator.free(write_buf);

    const output_path: []u8 = try std.fmt.allocPrint(
        allocator,
        "output/perlin_composite_{any}x{any}_zig_{s}.png",
        .{ save_chunks_per_side, save_chunks_per_side, mode_str },
    );
    defer allocator.free(output_path);

    try img.writeToFilePath(allocator, output_path, write_buf, .{ .png = .{} });
    std.debug.print("Saved composite to {s}\n", .{output_path});
}
