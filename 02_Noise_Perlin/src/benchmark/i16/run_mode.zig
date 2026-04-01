const std = @import("std");

const config = @import("../config.zig");
const report = @import("../report.zig");
const runner = @import("../runner.zig");
const image_writer = @import("image_writer.zig");
const registry = @import("../../noise/perlin/registry.zig");

pub fn run_mode_i16(
	allocator: std.mem.Allocator,
	stdout: anytype,
	stderr: anytype,
	comptime spec: registry.ModeSpec,
	mode_str: []const u8,
	warmup_chunks: u64,
	benchmark_chunks: u64,
	save_chunks_per_side: u64,
) !void {
	const mod = spec.module;
	const alloc_alignment = comptime std.mem.Alignment.fromByteUnits(spec.required_alignment);

	const values_buffer = try allocator.alignedAlloc(i16, alloc_alignment, config.SCALE);
	defer allocator.free(values_buffer);

	const smoothed_values_buffer = try allocator.alignedAlloc(i16, alloc_alignment, config.SCALE);
	defer allocator.free(smoothed_values_buffer);

	const perlin_cfg = mod.perlin_init_config(
		values_buffer,
		smoothed_values_buffer,
		config.SEED,
		config.CHUNK_SIZE,
		config.SCALE,
		config.OCTAVES,
		config.PERSISTENCE,
		config.LACUNARITY,
	);

	const cs_usize: usize = @intCast(perlin_cfg.chunk_size);
	const chunk_buffer = try allocator.alignedAlloc(i16, alloc_alignment, cs_usize * cs_usize);
	defer allocator.free(chunk_buffer);

	const grids_per_side: u64 = @max(config.CHUNK_SIZE / config.SCALE, @as(u64, 1));
	const gps: usize = @intCast(grids_per_side + 1);

	switch (spec.grad_layout) {
		.soa => {
			var gc_buffer_soa: [2][gps * gps]i16 = undefined;
			const gc_buffer_soa_slice = [2][]i16{ &gc_buffer_soa[0], &gc_buffer_soa[1] };

			try runner.run_warmup(mod, perlin_cfg, chunk_buffer, gc_buffer_soa_slice, warmup_chunks);
			const benchmark_result = try runner.run_benchmark_pass(mod, perlin_cfg, chunk_buffer, gc_buffer_soa_slice, benchmark_chunks);

			const total_points = benchmark_chunks * perlin_cfg.chunk_size * perlin_cfg.chunk_size;
			try report.print_benchmark_report(
				stdout, 
				benchmark_chunks, 
				total_points, 
				benchmark_result
			);

			try image_writer.write_composite_image(
				allocator,
				stdout,
				stderr,
				mod,
				perlin_cfg,
				chunk_buffer,
				gc_buffer_soa_slice,
				mode_str,
				save_chunks_per_side,
			);
		},
		.aos => {
			@compileError("i16 modes with AoS gradient layout are not supported");
		},
	}
}
