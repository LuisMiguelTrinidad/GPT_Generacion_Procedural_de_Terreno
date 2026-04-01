const std = @import("std");
const config = @import("../config.zig");
const image_types = @import("types.zig");

pub fn build_composite_gray8(
	comptime mod: type,
	comptime Sample: type,
	comptime sample_to_gray8: fn (Sample) u8,
	perlin_cfg: anytype,
	chunk_buffer: []Sample,
	gc_buffer: anytype,
	allocator: std.mem.Allocator,
	save_chunks_per_side: u64,
) !image_types.Gray8Image {
	const has_workspace = comptime @hasDecl(mod, "workspace_bytes") and @hasDecl(mod, "WorkspaceAlignment");
	const workspace_bytes = comptime if (has_workspace) mod.workspace_bytes(config.CHUNK_SIZE, config.SCALE) else 0;
	const workspace_alignment = comptime if (has_workspace) mod.WorkspaceAlignment else 1;

	var workspace_buffer: [workspace_bytes]u8 align(workspace_alignment) = undefined;

	const cs_usize: usize = @intCast(perlin_cfg.chunk_size);
	const chunks_per_side_usize: usize = @intCast(save_chunks_per_side);

	const width: usize = cs_usize * chunks_per_side_usize;
	const height: usize = cs_usize * chunks_per_side_usize;
	const image_bytes = try allocator.alloc(u8, width * height);
	errdefer allocator.free(image_bytes);

	const save_chunks_i64: i64 = @intCast(save_chunks_per_side);
	const half: i64 = @divFloor(save_chunks_i64, 2);

	const min_idx: i64 = -half;
	const max_idx: i64 = save_chunks_i64 - half;

	var workspace_fba = std.heap.FixedBufferAllocator.init(&workspace_buffer);
	const workspace_allocator = workspace_fba.allocator();

	var y_idx: i64 = min_idx;
	while (y_idx < max_idx) : (y_idx += 1) {
		var x_idx: i64 = min_idx;
		while (x_idx < max_idx) : (x_idx += 1) {
			const eval_y = save_chunks_i64 - 1 - y_idx;

			workspace_fba.reset();
			try mod.perlin_generate_chunk2d(perlin_cfg, x_idx, eval_y, chunk_buffer, gc_buffer, workspace_allocator);

			for (0..cs_usize) |row| {
				const grid_y: usize = @intCast(y_idx - min_idx);
				const global_y = grid_y * cs_usize + row;

				for (0..cs_usize) |col| {
					const grid_x: usize = @intCast(x_idx - min_idx);
					const global_x = grid_x * cs_usize + col;

					const sample = chunk_buffer[row * cs_usize + col];
					image_bytes[global_y * width + global_x] = sample_to_gray8(sample);
				}
			}
		}
	}

	return .{
		.width = width,
		.height = height,
		.pixels = image_bytes,
	};
}