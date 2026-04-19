const std = @import("std");
const config = @import("../config.zig");
const image_types = @import("types.zig");
const registry = @import("../../noise/perlin/registry.zig");

pub fn build_composite_gray8(
	comptime mode: registry.OptMode,
	comptime Sample: type,
	comptime sample_to_gray8: fn (Sample) u8,
	seed: u64,
	cached_values: anytype,
	cached_smoothed_values: anytype,
	chunk_buffer: []Sample,
	allocator: std.mem.Allocator,
	save_chunks_per_side: u64,
) !image_types.Gray8Image {
	const mode_scratch = comptime registry.get_mode_scratch_spec(mode, config.CHUNK_SIZE, config.SCALE);

	var gradient_cache_buffer: [mode_scratch.gradient_cache_bytes]u8 align(mode_scratch.gradient_cache_alignment) = undefined;

	const cs_usize: usize = @intCast(config.CHUNK_SIZE);
	const chunks_per_side_usize: usize = @intCast(save_chunks_per_side);

	const width: usize = cs_usize * chunks_per_side_usize;
	const height: usize = cs_usize * chunks_per_side_usize;
	const image_bytes = try allocator.alloc(u8, width * height);
	errdefer allocator.free(image_bytes);

	const save_chunks_i64: i64 = @intCast(save_chunks_per_side);
	const chunk_size_i64: i64 = @as(i64, @intCast(config.CHUNK_SIZE));
	const half: i64 = @divTrunc(save_chunks_i64, 2);

	const min_idx: i64 = -half;
	const max_idx: i64 = save_chunks_i64 - half;

	const grid_size: usize = @intCast(max_idx - min_idx);
	for (0..grid_size) |grid_y| {
		for (0..grid_size) |grid_x| {

			const y_idx: i64 = min_idx + @as(i64, @intCast(grid_y));
			const x_idx: i64 = min_idx + @as(i64, @intCast(grid_x));

			const eval_y = save_chunks_i64 - 1 - y_idx;
			const world_x: i64 = x_idx * chunk_size_i64;
			const world_y: i64 = eval_y * chunk_size_i64;

			try registry.generate_chunk2d(
				mode,
				config.CHUNK_SIZE,
				config.SCALE,
				config.OCTAVES,
				seed,
				cached_values,
				cached_smoothed_values,
				world_x,
				world_y,
				chunk_buffer,
				gradient_cache_buffer[0..mode_scratch.gradient_cache_bytes],
			);

			for (0..cs_usize) |row| {
				const global_y = grid_y * cs_usize + row;

				for (0..cs_usize) |col| {
					const global_x = grid_x * cs_usize + col;

					const sample = chunk_buffer[row * cs_usize + col];
					image_bytes[global_y * width + global_x] = sample_to_gray8(sample);
				}
			}
		}
	}

	return .{
		.width = width,
		.height = height,
		.pixels = image_bytes,
	};
}