const std = @import("std");
const config = @import("config.zig");

pub const BenchmarkResult = struct {
	total_cycles: u64,
	best_chunk_cycles: u64,
};

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

	const cycles_per_point = @as(f64, @floatFromInt(result.total_cycles)) / total_points_f64;
	const perf_points_sec_base = total_points_f64 / total_time_sec_base / 1e6;
	const perf_points_sec_turbo = total_points_f64 / total_time_sec_turbo / 1e6;

	// Métricas máximas (mejor chunk)
	const chunk_points = total_points / total_chunks;
	const chunk_points_f64 = @as(f64, @floatFromInt(chunk_points));
	const best_chunk_cycles_f64 = @as(f64, @floatFromInt(result.best_chunk_cycles));
	const best_chunk_time_sec_base = best_chunk_cycles_f64 / config.CPU_BASE_FREQ;
	const best_chunk_time_sec_turbo = best_chunk_cycles_f64 / config.CPU_FREQ;

	const best_chunk_cycles_per_point = @as(f64, @floatFromInt(result.best_chunk_cycles)) /
		chunk_points_f64;
	const best_chunk_perf_points_sec_base = chunk_points_f64 / best_chunk_time_sec_base / 1e6;
	const best_chunk_perf_points_sec_turbo = chunk_points_f64 / best_chunk_time_sec_turbo / 1e6;

	try stdout.print("\nFrecuencia base:  {d:.2} GHz --RECUERDA desactivar el turbo boost--\n", .{cpu_base_ghz});
	try stdout.print("Frecuencia turbo: {d:.2} GHz\n\n", .{cpu_turbo_ghz});

	try stdout.print("Velocidad media (base):  {d:.0}M points/s\n", .{perf_points_sec_base});
	try stdout.print("Velocidad media (turbo): {d:.0}M points/s\n", .{perf_points_sec_turbo});
	try stdout.print("Eficiencia media:  {d:.3} cycles/punto (Reference Cycles)\n\n", .{cycles_per_point});

	try stdout.print("Velocidad máxima (base):  {d:.0}M points/s\n", .{best_chunk_perf_points_sec_base});
	try stdout.print("Velocidad máxima (turbo): {d:.0}M points/s\n", .{best_chunk_perf_points_sec_turbo});
	try stdout.print("Eficiencia máxima:  {d:.4} cycles/punto (Reference Cycles)\n", .{best_chunk_cycles_per_point});
}