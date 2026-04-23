const std = @import("std");
const config = @import("config.zig");

const TOP_LEFT = "┌";
const TOP_RIGHT = "┐";
const BOTTOM_LEFT = "└";
const BOTTOM_RIGHT = "┘";
const JUNCTION = "┼";
const BOTTOM_JUNCTION = "┴";
const HORIZONTAL = "─";
const VERTICAL = "│";

const HEADER_WIDTH: usize = 11;
const VALUE_WIDTH: usize = 10;

pub const BenchmarkResult = struct {
	total_cycles: u64,
	best_chunk_cycles: u64,
};

fn print_horizontal(stdout: anytype, width: usize) !void {
	for (0..width) |_| {
		try stdout.print("{s}", .{HORIZONTAL});
	}
}

fn print_border(stdout: anytype, dim_count: usize) !void {
	try stdout.print("{s}", .{TOP_LEFT});
	try print_horizontal(stdout, HEADER_WIDTH + 2);
	for (0..dim_count) |_| {
		try stdout.print("{s}", .{JUNCTION});
		try print_horizontal(stdout, VALUE_WIDTH + 2);
	}
	try stdout.print("{s}\n", .{TOP_RIGHT});
}

fn print_bottom_border(stdout: anytype, dim_count: usize) !void {
	try stdout.print("{s}", .{BOTTOM_LEFT});
	try print_horizontal(stdout, HEADER_WIDTH + 2);
	for (0..dim_count) |_| {
		try stdout.print("{s}", .{BOTTOM_JUNCTION});
		try print_horizontal(stdout, VALUE_WIDTH + 2);
	}
	try stdout.print("{s}\n", .{BOTTOM_RIGHT});
}

fn print_separator(stdout: anytype, dim_count: usize) !void {
	try stdout.print("{s}", .{JUNCTION});
	try print_horizontal(stdout, HEADER_WIDTH + 2);
	for (0..dim_count) |_| {
		try stdout.print("{s}", .{JUNCTION});
		try print_horizontal(stdout, VALUE_WIDTH + 2);
	}
	try stdout.print("{s}\n", .{JUNCTION});
}

pub fn average_cycles_per_point(total_points: u64, result: BenchmarkResult) f64 {
	if (total_points == 0) {
		return 0.0;
	}

	const total_points_f64 = @as(f64, @floatFromInt(total_points));
	const total_cycles_f64 = @as(f64, @floatFromInt(result.total_cycles));
	return total_cycles_f64 / total_points_f64;
}

pub fn max_cycles_per_point(total_chunks: u64, total_points: u64, result: BenchmarkResult) f64 {
	if (total_chunks == 0 or total_points == 0) {
		return 0.0;
	}

	const chunk_points = total_points / total_chunks;
	if (chunk_points == 0) {
		return 0.0;
	}

	const chunk_points_f64 = @as(f64, @floatFromInt(chunk_points));
	const best_chunk_cycles_f64 = @as(f64, @floatFromInt(result.best_chunk_cycles));
	return best_chunk_cycles_f64 / chunk_points_f64;
}

pub fn print_comparison_table(
	stdout: anytype,
	title: []const u8,
	sweep_values: []const u64,
	cycles_cells: []const ?f64,
) !void {
	const dim_count = sweep_values.len;
	if (cycles_cells.len != dim_count * dim_count) {
		return error.InvalidComparisonTableShape;
	}

	try stdout.print("\n{s}\n", .{title});
	try print_border(stdout, dim_count);

	try stdout.print("{s} {s:>11} {s}", .{ VERTICAL, "CHUNK/SCALE", VERTICAL });
	for (sweep_values) |scale| {
		try stdout.print(" {d:>10} {s}", .{ scale, VERTICAL });
	}
	try stdout.print("\n", .{});

	try print_separator(stdout, dim_count);

	for (sweep_values, 0..) |chunk_size, row_idx| {
		try stdout.print("{s} {d:>11} {s}", .{ VERTICAL, chunk_size, VERTICAL });
		for (sweep_values, 0..) |_, col_idx| {
			const flat_idx = row_idx * dim_count + col_idx;
			if (cycles_cells[flat_idx]) |cycles| {
				try stdout.print(" {d:>10.4} {s}", .{ cycles, VERTICAL });
			} else {
				try stdout.print(" {s:>10} {s}", .{ "N/A", VERTICAL });
			}
		}
		try stdout.print("\n", .{});
	}

	try print_bottom_border(stdout, dim_count);
}

pub fn print_benchmark_report(
	stdout: anytype,
	total_chunks: u64,
	total_points: u64,
	result: BenchmarkResult,
) !void {
	const total_points_f64 = @as(f64, @floatFromInt(total_points));
	const cpu_base_ghz = config.CPU_BASE_FREQ / 1_000_000_000.0;
	const cpu_turbo_ghz = config.CPU_FREQ / 1_000_000_000.0;

	const total_cycles_f64 = @as(f64, @floatFromInt(result.total_cycles));
	const total_time_sec_base = total_cycles_f64 / config.CPU_BASE_FREQ;
	const total_time_sec_turbo = total_cycles_f64 / config.CPU_FREQ;

	const avg_cycles = average_cycles_per_point(total_points, result);
	const perf_points_sec_base = total_points_f64 / total_time_sec_base / 1e6;
	const perf_points_sec_turbo = total_points_f64 / total_time_sec_turbo / 1e6;

	// Métricas máximas (mejor chunk)
	const chunk_points = total_points / total_chunks;
	const chunk_points_f64 = @as(f64, @floatFromInt(chunk_points));
	const best_chunk_cycles_f64 = @as(f64, @floatFromInt(result.best_chunk_cycles));
	const best_chunk_time_sec_base = best_chunk_cycles_f64 / config.CPU_BASE_FREQ;
	const best_chunk_time_sec_turbo = best_chunk_cycles_f64 / config.CPU_FREQ;

	const best_chunk_cycles_per_point = max_cycles_per_point(total_chunks, total_points, result);
	const best_chunk_perf_points_sec_base = chunk_points_f64 / best_chunk_time_sec_base / 1e6;
	const best_chunk_perf_points_sec_turbo = chunk_points_f64 / best_chunk_time_sec_turbo / 1e6;

	try stdout.print("\nFrecuencia base:  {d:.2} GHz --RECUERDA desactivar el turbo boost--\n", .{cpu_base_ghz});
	try stdout.print("Frecuencia turbo: {d:.2} GHz\n\n", .{cpu_turbo_ghz});

	try stdout.print("Velocidad media (base):  {d:.0}M points/s\n", .{perf_points_sec_base});
	try stdout.print("Velocidad media (turbo): {d:.0}M points/s\n", .{perf_points_sec_turbo});
	try stdout.print("Eficiencia media:  {d:.3} cycles/punto (Reference Cycles)\n\n", .{avg_cycles});

	try stdout.print("Velocidad máxima (base):  {d:.0}M points/s\n", .{best_chunk_perf_points_sec_base});
	try stdout.print("Velocidad máxima (turbo): {d:.0}M points/s\n", .{best_chunk_perf_points_sec_turbo});
	try stdout.print("Eficiencia máxima:  {d:.4} cycles/punto (Reference Cycles)\n", .{best_chunk_cycles_per_point});
}