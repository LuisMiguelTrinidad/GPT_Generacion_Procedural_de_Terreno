const std = @import("std");
const config = @import("config.zig");
const report = @import("report.zig");
const cycle_counter = @import("../core/shared/cycle_counter.zig");
const registry = @import("../noise/perlin/registry.zig");

pub fn run_warmup(
	comptime mode: registry.OptMode,
	perlin_cfg: anytype,
	chunk_buffer: anytype,
	warmup_chunk_count: u64,
) !void {
	const scratch = comptime registry.get_mode_scratch_spec(mode, config.CHUNK_SIZE, config.SCALE);
	const gc_bytes = scratch.gc_bytes;
	const gc_alignment = scratch.gc_alignment;
	const workspace_bytes = scratch.workspace_bytes;
	const workspace_alignment = scratch.workspace_alignment;

	var gc_buffer: [gc_bytes]u8 align(gc_alignment) = undefined;
	var workspace_buffer: [workspace_bytes]u8 align(workspace_alignment) = undefined;

	for (0..warmup_chunk_count) |i| {
		try registry.generate_chunk2d(
			mode,
			config.CHUNK_SIZE,
			config.SCALE,
			perlin_cfg,
			@as(i64, @intCast(i)),
			@as(i64, @intCast(i)),
			chunk_buffer,
			gc_buffer[0..gc_bytes],
			workspace_buffer[0..workspace_bytes],
		);
	}
}

pub fn run_benchmark_pass(
	comptime mode: registry.OptMode,
	perlin_cfg: anytype,
	chunk_buffer: anytype,
	benchmark_chunk_count: u64,
) !report.BenchmarkResult {
	const start_cycles = cycle_counter.read();

	const scratch = comptime registry.get_mode_scratch_spec(mode, config.CHUNK_SIZE, config.SCALE);
	const gc_bytes = scratch.gc_bytes;
	const gc_alignment = scratch.gc_alignment;
	const workspace_bytes = scratch.workspace_bytes;
	const workspace_alignment = scratch.workspace_alignment;

	var gc_buffer: [gc_bytes]u8 align(gc_alignment) = undefined;
	var workspace_buffer: [workspace_bytes]u8 align(workspace_alignment) = undefined;

	var best_chunk_cycles: u64 = std.math.maxInt(u64);

	for (0..benchmark_chunk_count) |i| {
		const chunk_start_cycles = cycle_counter.read();

		try registry.generate_chunk2d(
			mode,
			config.CHUNK_SIZE,
			config.SCALE,
			perlin_cfg,
			@as(i64, @intCast(i)),
			@as(i64, @intCast(i)),
			chunk_buffer,
			gc_buffer[0..gc_bytes],
			workspace_buffer[0..workspace_bytes],
		);

		const chunk_end_cycles = cycle_counter.read();

		const chunk_cycles = chunk_end_cycles - chunk_start_cycles;

		best_chunk_cycles = @min(chunk_cycles, best_chunk_cycles);
	}

	const end_cycles = cycle_counter.read();

	return report.BenchmarkResult{
		.total_cycles = end_cycles - start_cycles,
		.best_chunk_cycles = best_chunk_cycles,
	};
}