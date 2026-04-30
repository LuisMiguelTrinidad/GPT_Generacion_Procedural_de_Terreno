const std = @import("std");
const mode_meta = @import("mode_meta.zig");

const perlin_O0 = @import("00_ref.zig");
const perlin_O1 = @import("01_custom_hash.zig");
const perlin_O2 = @import("02_caching.zig");
const perlin_O3 = @import("03_tiling.zig");
const perlin_O4 = @import("04_licm.zig");
const perlin_O5 = @import("05_simd.zig");
const perlin_O6 = @import("06_fpa.zig");
const perlin_O7 = @import("07_fractal.zig");

const mode_modules = .{
	.O0 = perlin_O0,
	.O1 = perlin_O1,
	.O2 = perlin_O2,
	.O3 = perlin_O3,
	.O4 = perlin_O4,
	.O5 = perlin_O5,
	.O6 = perlin_O6,
	.O7 = perlin_O7,
};

pub const OptMode = std.meta.FieldEnum(@TypeOf(mode_modules));
pub const SampleKind = mode_meta.SampleKind;

pub const ModeSpec = struct {
	module: type,
	sample_kind: SampleKind,
	required_alignment: u29,
};

pub const ScratchSpec = struct {
	gradient_cache_bytes: usize,
	gradient_cache_alignment: u29
};

fn mode_module(comptime mode: OptMode) type {
	return @field(mode_modules, @tagName(mode));
}

pub fn get_mode_spec(comptime mode: OptMode) ModeSpec {
	const mod = mode_module(mode);
	return .{
		.module = mod,
		.sample_kind = mod.sample_kind,
		.required_alignment = mod.RequiredAlignment,
	};
}

pub fn get_mode_scratch_spec(
	comptime mode: OptMode,
	comptime chunk_size: u64,
	comptime scale: u64,
) ScratchSpec {
	return switch (mode) {
		.O2 => .{
			.gradient_cache_bytes = perlin_O2.gradient_cache_bytes(chunk_size, scale),
			.gradient_cache_alignment = perlin_O2.GradientCacheAlignment,
		},
		else => .{
			.gradient_cache_bytes = 0,
			.gradient_cache_alignment = mode_meta.CacheLineBytes,
		},
	};
}

pub inline fn generate_chunk2d(
	comptime mode: OptMode,
	comptime chunk_size: u64,
	comptime scale: u64,
	comptime octaves: u64,
	seed: u64,
	cached_values: anytype,
	cached_smoothed_values: anytype,
	world_x: i64,
	world_y: i64,
	out_buffer: anytype,
	gradient_cache_buf: []u8,
) !void {
	switch (mode) {
		.O0 => {
			return perlin_O0.perlin_generate_chunk2d(seed, chunk_size, scale, world_x, world_y, out_buffer);
		},
		.O1 => {
			return perlin_O1.perlin_generate_chunk2d(seed, chunk_size, scale, world_x, world_y, out_buffer);
		},
		.O2 => {
			return perlin_O2.perlin_generate_chunk2d(seed, chunk_size, scale, cached_values, cached_smoothed_values, world_x, world_y, out_buffer, gradient_cache_buf);
		},
		.O3 => {
			return perlin_O3.perlin_generate_chunk2d(seed, chunk_size, scale, cached_values, cached_smoothed_values, world_x, world_y, out_buffer);
		},
		.O4 => {
			return perlin_O4.perlin_generate_chunk2d(
				seed,
				chunk_size,
				scale,
				cached_values,
				cached_smoothed_values,
				world_x,
				world_y,
				out_buffer,
			);
		},
		.O5 => {
			return perlin_O5.perlin_generate_chunk2d(
				seed,
				chunk_size,
				scale,
				cached_values,
				cached_smoothed_values,
				world_x,
				world_y,
				out_buffer,
			);
		},
		.O6 => {
			return perlin_O6.perlin_generate_chunk2d(
				seed,
				chunk_size,
				scale,
				cached_values,
				cached_smoothed_values,
				world_x,
				world_y,
				out_buffer,
			);
		},
		.O7 => {
			return perlin_O7.perlin_generate_chunk2d(
				seed,
				chunk_size,
				scale,
				octaves,
				cached_values,
				cached_smoothed_values,
				world_x,
				world_y,
				out_buffer,
			);
		}
	}
}

pub fn parse_mode(mode_arg: []const u8) ?OptMode {
	return std.meta.stringToEnum(OptMode, mode_arg);
}
