const std = @import("std");

pub const BenchmarkResult = struct {
	total_cycles: u64,
	total_time_nanos: u64,
	best_chunk_cycles: u64,
	best_chunk_nanos: u64,
};

pub fn print_benchmark_report(
	stdout: anytype,
	total_chunks: u64,
	total_points: u64,
	result: BenchmarkResult,
) !void {
	const total_time_sec = @as(f64, @floatFromInt(result.total_time_nanos)) / 1_000_000_000.0;
	const total_points_f64 = @as(f64, @floatFromInt(total_points));

	const perf_millions_sec = (total_points_f64 / total_time_sec) / 1_000_000.0;
	const cycles_per_point = @as(f64, @floatFromInt(result.total_cycles)) / total_points_f64;

	// Métricas máximas (mejor chunk)
	const chunk_points = total_points / total_chunks;
	const best_chunk_perf_millions_sec =
		(@as(f64, @floatFromInt(chunk_points)) /
			(@as(f64, @floatFromInt(result.best_chunk_nanos)) / 1_000_000_000.0)) /
		1_000_000.0;
	const best_chunk_cycles_per_point = @as(f64, @floatFromInt(result.best_chunk_cycles)) /
		@as(f64, @floatFromInt(chunk_points));

	try stdout.print("\nVelocidad media: {d:.6} million points/sec\n", .{perf_millions_sec});
	try stdout.print("Eficiencia media:  {d:.2} cycles/point (Reference Cycles)\n\n", .{cycles_per_point});
	try stdout.print("Velocidad máxima: {d:.6} million points/sec\n", .{best_chunk_perf_millions_sec});
	try stdout.print("Eficiencia máxima:  {d:.2} cycles/point (Reference Cycles)\n", .{best_chunk_cycles_per_point});
}