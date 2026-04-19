const std = @import("std");

const config = @import("../config.zig");
const report = @import("../report.zig");
const runner = @import("../runner.zig");
const image_writer = @import("image_writer.zig");
const registry = @import("../../noise/perlin/registry.zig");

pub fn run_mode_f32(
	comptime mode: registry.OptMode,
	allocator: std.mem.Allocator,
	stdout: anytype,
	stderr: anytype,
	comptime spec: registry.ModeSpec,
	mode_str: []const u8,
	warmup_chunk_count: u64,
	benchmark_chunk_count: u64,
	save_chunks_per_side: u64,
) !void {
	const mod = spec.module;
	const alloc_alignment = comptime std.mem.Alignment.fromByteUnits(spec.required_alignment);

	const values_buffer = try allocator.alignedAlloc(f32, alloc_alignment, config.SCALE);
	defer allocator.free(values_buffer);

	const smoothed_values_buffer = try allocator.alignedAlloc(f32, alloc_alignment, config.SCALE);
	defer allocator.free(smoothed_values_buffer);

	mod.perlin_prepare_cached_values(
		values_buffer,
		smoothed_values_buffer,
		config.CHUNK_SIZE,
		config.SCALE,
	);

	const chunk_buffer = try allocator.alignedAlloc(f32, alloc_alignment, config.CHUNK_SIZE * config.CHUNK_SIZE);
	defer allocator.free(chunk_buffer);

	try runner.run_warmup(
		mode,
		config.SEED,
		values_buffer,
		smoothed_values_buffer,
		chunk_buffer,
		warmup_chunk_count,
	);
	const benchmark_result = try runner.run_benchmark_pass(
		mode,
		config.SEED,
		values_buffer,
		smoothed_values_buffer,
		chunk_buffer,
		benchmark_chunk_count,
	);

	const total_points = benchmark_chunk_count * config.CHUNK_SIZE * config.CHUNK_SIZE;
	try report.print_benchmark_report(
		stdout,
		benchmark_chunk_count,
		total_points,
		benchmark_result,
	);

	try image_writer.write_composite_image(
		allocator,
		stdout,
		stderr,
		mode,
		config.SEED,
		values_buffer,
		smoothed_values_buffer,
		chunk_buffer,
		mode_str,
		save_chunks_per_side,
	);
}
