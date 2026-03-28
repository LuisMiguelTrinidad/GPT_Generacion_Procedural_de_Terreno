const std = @import("std");

pub const BenchmarkResult = struct {
    total_cycles: u64,
    total_time_nanos: u64,
};

pub fn print_benchmark_report(
    total_chunks: u64,
    total_points: u64,
    result: BenchmarkResult,
) void {
    const total_time_sec = @as(f64, @floatFromInt(result.total_time_nanos)) / 1_000_000_000.0;
    const total_points_f64 = @as(f64, @floatFromInt(total_points));

    const millions_points = total_points / 1_000_000;
    const perf_millions_sec = (total_points_f64 / total_time_sec) / 1_000_000.0;
    const cycles_per_point = @as(f64, @floatFromInt(result.total_cycles)) / total_points_f64;

    std.debug.print("\nTotal: {} chunks, {} millions of points in {d:.6} seconds\n", .{ total_chunks, millions_points, total_time_sec });
    std.debug.print("Performance: {d:.6} million points/sec\n", .{perf_millions_sec});
    std.debug.print("Efficiency:  {d:.2} cycles/point (Reference Cycles)\n\n", .{cycles_per_point});
}