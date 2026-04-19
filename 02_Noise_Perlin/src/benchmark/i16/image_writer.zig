const std = @import("std");
const composite_builder = @import("../image/composite_builder.zig");
const output_naming = @import("../image/output_naming.zig");
const png_writer = @import("../image/png_writer.zig");
const registry = @import("../../noise/perlin/registry.zig");

fn sample_to_gray8(sample: i16) u8 {
	return @intCast((@as(u16, @bitCast(sample)) ^ 0x2000) >> 6);
}

pub fn write_composite_image(
	allocator: std.mem.Allocator,
	stdout: anytype,
	stderr: anytype,
	comptime mode: registry.OptMode,
	seed: u64,
	cached_values: []const i16,
	cached_smoothed_values: []const i16,
	chunk_buffer: []i16,
	mode_str: []const u8,
	save_chunks_per_side: u64,
) !void {
	const image = try composite_builder.build_composite_gray8(
		mode,
		i16,
		sample_to_gray8,
		seed,
		cached_values,
		cached_smoothed_values,
		chunk_buffer,
		allocator,
		save_chunks_per_side,
	);
	errdefer allocator.free(image.pixels);

	const output_path = try output_naming.make_composite_output_path(allocator, mode_str, save_chunks_per_side);
	defer allocator.free(output_path);

	try png_writer.write_gray8_png_owned(allocator, stdout, stderr, image, output_path);
}