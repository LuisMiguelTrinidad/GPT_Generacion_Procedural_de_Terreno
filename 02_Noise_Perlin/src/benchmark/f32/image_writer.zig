const std = @import("std");
const composite_builder = @import("../image/composite_builder.zig");
const output_naming = @import("../image/output_naming.zig");
const png_writer = @import("../image/png_writer.zig");

fn sample_to_gray8(sample: f32) u8 {
	return @intFromFloat(@min(@max((sample + 1.0) * 127.5, 0.0), 255.0));
}

pub fn write_composite_image(
	allocator: std.mem.Allocator,
	stdout: anytype,
	stderr: anytype,
	comptime mod: type,
	perlin_cfg: anytype,
	chunk_buffer: []f32,
	gc_buffer: anytype,
	mode_str: []const u8,
	save_chunks_per_side: u64,
) !void {
	const image = try composite_builder.build_composite_gray8(
		mod,
		f32,
		sample_to_gray8,
		perlin_cfg,
		chunk_buffer,
		gc_buffer,
		allocator,
		save_chunks_per_side,
	);
	errdefer allocator.free(image.pixels);

	const output_path = try output_naming.make_composite_output_path(allocator, mode_str, save_chunks_per_side);
	defer allocator.free(output_path);

	try png_writer.write_gray8_png_owned(allocator, stdout, stderr, image, output_path);
}
