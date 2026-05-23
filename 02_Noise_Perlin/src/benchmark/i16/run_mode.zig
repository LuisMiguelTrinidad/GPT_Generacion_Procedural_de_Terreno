const std = @import("std");

const config = @import("../config.zig");
const report = @import("../report.zig");
const runner = @import("../runner.zig");
const image_writer = @import("image_writer.zig");
const registry = @import("../../noise/perlin/registry.zig");

const CellMetrics = struct {
	avg_cycles_per_point: f64,
	max_cycles_per_point: f64,
};

fn benchmark_cell_metrics(
	comptime mode: registry.OptMode,
	allocator: std.mem.Allocator,
	comptime spec: registry.ModeSpec,
	comptime chunk_size: u64,
	comptime scale: u64,
	warmup_chunk_count: u64,
	benchmark_chunk_count: u64,
) !CellMetrics {
	const mod = spec.module;
	const alloc_alignment = comptime std.mem.Alignment.fromByteUnits(spec.required_alignment);

	const scale_usize: usize = @intCast(scale);
	const chunk_size_usize: usize = @intCast(chunk_size);

	const values_buffer = try allocator.alignedAlloc(i16, alloc_alignment, scale_usize);
	defer allocator.free(values_buffer);

	const smoothed_values_buffer = try allocator.alignedAlloc(i16, alloc_alignment, scale_usize);
	defer allocator.free(smoothed_values_buffer);

	mod.perlin_prepare_cached_values(
		values_buffer,
		smoothed_values_buffer,
		chunk_size,
		scale,
	);

	const chunk_buffer = try allocator.alignedAlloc(i16, alloc_alignment, chunk_size_usize * chunk_size_usize);
	defer allocator.free(chunk_buffer);

	try runner.run_warmup(
		mode,
		chunk_size,
		scale,
		config.SEED,
		values_buffer,
		smoothed_values_buffer,
		chunk_buffer,
		warmup_chunk_count,
	);

	const benchmark_result = try runner.run_benchmark_pass(
		mode,
		chunk_size,
		scale,
		config.SEED,
		values_buffer,
		smoothed_values_buffer,
		chunk_buffer,
		benchmark_chunk_count,
	);

	const total_points = benchmark_chunk_count * chunk_size * chunk_size;
	return .{
		.avg_cycles_per_point = report.average_cycles_per_point(total_points, benchmark_result),
		.max_cycles_per_point = report.max_cycles_per_point(benchmark_chunk_count, total_points, benchmark_result),
	};
}

pub fn run_mode_i16(
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
	const chunk_sizes = config.BENCHMARK_CHUNK_SIZES;
	const scales = config.BENCHMARK_SCALES;
	const row_count = chunk_sizes.len;
	const col_count = scales.len;
	const cell_count = row_count * col_count;
	var avg_cells: [cell_count]?f64 = [_]?f64{null} ** cell_count;
	var max_cells: [cell_count]?f64 = [_]?f64{null} ** cell_count;

	try stdout.print("\nModo {s}\n", .{mode_str});

	inline for (chunk_sizes, 0..) |chunk_size, row_idx| {
		inline for (scales, 0..) |scale, col_idx| {
			const flat_idx = row_idx * col_count + col_idx;
			const metrics = try benchmark_cell_metrics(
				mode,
				allocator,
				spec,
				chunk_size,
				scale,
				warmup_chunk_count,
				benchmark_chunk_count,
			);

			avg_cells[flat_idx] = metrics.avg_cycles_per_point;
			max_cells[flat_idx] = metrics.max_cycles_per_point;
		}
	}

	try report.print_comparison_table(
		stdout,
		"Promedio de cycles/punto",
		chunk_sizes[0..],
		scales[0..],
		avg_cells[0..],
	);
	try report.print_comparison_table(
		stdout,
		"Maximo de cycles/punto (mejor chunk)",
		chunk_sizes[0..],
		scales[0..],
		max_cells[0..],
	);

	if (save_chunks_per_side == 0) {
		return;
	}

	const mod = spec.module;
	const alloc_alignment = comptime std.mem.Alignment.fromByteUnits(spec.required_alignment);
	const scale_usize: usize = @intCast(config.SCALE);
	const chunk_size_usize: usize = @intCast(config.CHUNK_SIZE);

	const values_buffer = try allocator.alignedAlloc(i16, alloc_alignment, scale_usize);
	defer allocator.free(values_buffer);

	const smoothed_values_buffer = try allocator.alignedAlloc(i16, alloc_alignment, scale_usize);
	defer allocator.free(smoothed_values_buffer);

	mod.perlin_prepare_cached_values(
		values_buffer,
		smoothed_values_buffer,
		config.CHUNK_SIZE,
		config.SCALE,
	);

	const chunk_buffer = try allocator.alignedAlloc(i16, alloc_alignment, chunk_size_usize * chunk_size_usize);
	defer allocator.free(chunk_buffer);

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
