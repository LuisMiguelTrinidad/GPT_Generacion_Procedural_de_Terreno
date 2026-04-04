const std = @import("std");

const config = @import("config.zig");
const registry = @import("../noise/perlin/registry.zig");
const run_mode_f32 = @import("f32/run_mode.zig");
const run_mode_i16 = @import("i16/run_mode.zig");

pub const OptMode = registry.OptMode;

pub fn run_mode(comptime mode: OptMode, allocator: std.mem.Allocator, stdout: anytype, stderr: anytype) !void {
	const mode_str = @tagName(mode);
	const spec = comptime registry.get_mode_spec(mode);

	const warmup_chunk_count: u64 = config.WARMUP_CHUNK_COUNT;
	const benchmark_chunk_count: u64 = config.BENCHMARK_CHUNK_COUNT;
	const save_chunks_per_side: u64 = config.SAVE_CHUNKS_PER_SIDE;

	switch (spec.sample_kind) {
		.f32 => try run_mode_f32.run_mode_f32(
			mode,
			allocator,
			stdout,
			stderr,
			spec,
			mode_str,
			warmup_chunk_count,
			benchmark_chunk_count,
			save_chunks_per_side,
		),
		.i16 => try run_mode_i16.run_mode_i16(
			mode,
			allocator,
			stdout,
			stderr,
			spec,
			mode_str,
			warmup_chunk_count,
			benchmark_chunk_count,
			save_chunks_per_side,
		),
	}
}

pub fn parse_mode(mode_arg: []const u8) ?OptMode {
	return registry.parse_mode(mode_arg);
}
