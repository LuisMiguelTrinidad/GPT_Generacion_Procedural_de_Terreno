const std = @import("std");
const config = @import("config.zig");
const report = @import("report.zig");
const cycle_counter = @import("../core/shared/cycle_counter.zig");

pub fn run_warmup(
	comptime mod: type,
	perlin_cfg: anytype,
	chunk_buffer: anytype,
	gc_buffer: anytype,
	warmup_chunks_per_side: u64,
) !void {
	const has_workspace = comptime @hasDecl(mod, "workspace_bytes") and @hasDecl(mod, "WorkspaceAlignment");
	const workspace_bytes = comptime if (has_workspace) mod.workspace_bytes(config.CHUNK_SIZE, config.SCALE) else 0;
	const workspace_alignment = comptime if (has_workspace) mod.WorkspaceAlignment else 1;

	var workspace_buffer: [workspace_bytes]u8 align(workspace_alignment) = undefined;
	var workspace_fba = std.heap.FixedBufferAllocator.init(&workspace_buffer);
	const workspace_allocator = workspace_fba.allocator();

	for (0..warmup_chunks_per_side) |i| {
		workspace_fba.reset();

		try mod.perlin_generate_chunk2d(
			perlin_cfg,
			@as(i64, @intCast(i)),
			@as(i64, @intCast(i)),
			chunk_buffer,
			gc_buffer,
			workspace_allocator,
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

	const has_workspace = comptime @hasDecl(mod, "workspace_bytes") and @hasDecl(mod, "WorkspaceAlignment");
	const workspace_bytes = comptime if (has_workspace) mod.workspace_bytes(config.CHUNK_SIZE, config.SCALE) else 0;
	const workspace_alignment = comptime if (has_workspace) mod.WorkspaceAlignment else 1;

	var workspace_buffer: [workspace_bytes]u8 align(workspace_alignment) = undefined;
	var workspace_fba = std.heap.FixedBufferAllocator.init(&workspace_buffer);
	const workspace_allocator = workspace_fba.allocator();

	var best_chunk_cycles: u64 = std.math.maxInt(u64);
	var best_chunk_nanos: u64 = std.math.maxInt(u64);

	for (0..benchmark_chunks_per_side) |i| {
		workspace_fba.reset();

		const chunk_start_cycles = cycle_counter.read();
		const chunk_start_nanos = timer.read();

		try mod.perlin_generate_chunk2d(
			perlin_cfg,
			@as(i64, @intCast(i)),
			@as(i64, @intCast(i)),
			chunk_buffer,
			gc_buffer,
			workspace_allocator,
		);

		const chunk_end_cycles = cycle_counter.read();
		const chunk_end_nanos = timer.read();

		const chunk_cycles = chunk_end_cycles - chunk_start_cycles;
		const chunk_nanos = chunk_end_nanos - chunk_start_nanos;

		best_chunk_cycles = @min(chunk_cycles, best_chunk_cycles);
		best_chunk_nanos = @min(chunk_nanos, best_chunk_nanos);
	}

	const end_cycles = cycle_counter.read();
	const total_time_nanos = timer.read();

	return report.BenchmarkResult{
		.total_cycles = end_cycles - start_cycles,
		.total_time_nanos = total_time_nanos,
		.best_chunk_cycles = best_chunk_cycles,
		.best_chunk_nanos = best_chunk_nanos,
	};
}