const std = @import("std");
const report = @import("report.zig");
const scratch = @import("scratch.zig");
const cycle_counter = @import("../core/shared/cycle_counter.zig");

pub fn run_warmup(
    comptime mod: type,
    perlin_cfg: anytype,
    chunk_buffer: anytype,
    gc_buffer: anytype,
    warmup_chunks_per_side: u64,
) void {
    const scratch_bytes = comptime scratch.bytes_for_mod(mod);
    const scratch_align = comptime scratch.alignment_for_mod(mod);
    var scratch_buffer: [scratch_bytes]u8 align(scratch_align) = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch_buffer);
    const scratch_allocator = fba.allocator();

    for (0..warmup_chunks_per_side) |i| {
        fba.reset();

        mod.perlin_generate_chunk2d(
            perlin_cfg,
            @as(i64, @intCast(i)),
            @as(i64, @intCast(i)),
            chunk_buffer,
            gc_buffer,
            scratch_allocator,
        );
    }
}

pub fn run_benchmark_pass(
    comptime mod: type,
    perlin_cfg: anytype,
    chunk_buffer: anytype,
    gc_buffer: anytype,
    benchmark_chunks_per_side: u64,
) !report.BenchmarkResult {
    var timer = try std.time.Timer.start();
    const start_cycles = cycle_counter.read();

    const scratch_bytes = comptime scratch.bytes_for_mod(mod);
    const scratch_align = comptime scratch.alignment_for_mod(mod);
    var scratch_buffer: [scratch_bytes]u8 align(scratch_align) = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch_buffer);
    const scratch_allocator = fba.allocator();

    for (0..benchmark_chunks_per_side) |i| {
        fba.reset();

        mod.perlin_generate_chunk2d(
            perlin_cfg,
            @as(i64, @intCast(i)),
            @as(i64, @intCast(i)),
            chunk_buffer,
            gc_buffer,
            scratch_allocator,
        );
    }

    const end_cycles = cycle_counter.read();
    const total_time_nanos = timer.read();

    return report.BenchmarkResult{
        .total_cycles = end_cycles - start_cycles,
        .total_time_nanos = total_time_nanos,
    };

}