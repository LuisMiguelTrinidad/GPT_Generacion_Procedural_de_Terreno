const table = @import("../../core/f32/table.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

pub const RequiredAlignment: u29 = @alignOf(f32);
pub const sample_kind: mode_meta.SampleKind = .f32;

pub fn workspace_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
	const min_dim: u64 = @min(chunk_size, scale);
	return @as(usize, @intCast(min_dim)) * @sizeOf(f32) * 3;
}

comptime {
	if (@popCount(@as(u64, RequiredAlignment)) != 1) {
		@compileError("RequiredAlignment must be a non-zero power of two");
	}
}

inline fn lerp_scalar(a: f32, b: f32, t: f32) f32 {
	const diff: f32 = b - a;
	return @mulAdd(f32, t, diff, a);
}

pub inline fn perlin_prepare_seed(seed: u64) u64 {
	return hash.custom_hash_init_v1(seed);
}

pub inline fn perlin_prepare_cached_values(
	values_buf: []f32,
	smoothed_buf: []f32,
	comptime chunk_size: u64,
	comptime scale: u64,
) void {
	comptime {
		if ((@popCount(scale) != 1)) {
			@compileError("O4 requires SCALE to be a power of two");
		}
	}

	_ = chunk_size;

	for (0..scale) |i| {
		const if32: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(scale));
		values_buf[i] = if32;
		smoothed_buf[i] = math.smooth_step(if32);
	}
}

pub fn perlin_generate_chunk2d(
	seed: u64,
	comptime chunk_size: u64,
	comptime scale: u64,
	cached_values: []const f32,
	cached_smoothed_values: []const f32,
	world_x: i64,
	world_y: i64,
	noalias out_buffer: []f32,
) !void {
	@setFloatMode(.optimized);
	const initialized_seed: u64 = hash.custom_hash_init_v1(seed);

	const cs_u: u64 = chunk_size;
	const cs_l: u6 = @as(u6, @intCast(@ctz(cs_u)));

	const sc_u: u64 = scale;
	const sc_m: u64 = sc_u - 1;
	const sc_l: u6 = @as(u6, @intCast(@ctz(sc_u)));

	const grid_base_x: i64 = world_x >> sc_l;
	const grid_base_y: i64 = world_y >> sc_l;

	const n_cells: u64 = @max(cs_u >> sc_l, @as(u64, 1));

	const arr_world_off_x_u: u64 = @as(u64, @bitCast(world_x)) & sc_m;
	const arr_world_off_y_u: u64 = @as(u64, @bitCast(world_y)) & sc_m;

	const min_dim: u64 = comptime @min(chunk_size, scale);
	const elem_count: usize = comptime @as(usize, @intCast(min_dim));

	const x_rel_cache = cached_values.ptr + arr_world_off_x_u;
	const s_x_cache = cached_smoothed_values.ptr + arr_world_off_x_u;

	var s_x_cache_arr: [elem_count]f32 = undefined;
	var i_x0_cache_arr: [elem_count]f32 = undefined;
	var delta_i_x_cache_arr: [elem_count]f32 = undefined;

	for (0..n_cells) |gy| {
		const noise_local_tile_y_u: u64 = n_cells - gy - 1;
		const arr_world_tile_y_u: u64 = noise_local_tile_y_u << sc_l;

		for (0..n_cells) |gx| {
			const arr_world_tile_x_u: u64 = gx << sc_l;
			const grid_x0: i64 = grid_base_x + @as(i64, @intCast(gx));
			const grid_y0: i64 = grid_base_y + @as(i64, @intCast(gy));
			const grid_x1: i64 = grid_x0 + 1;
			const grid_y1: i64 = grid_y0 + 1;

			const g_idx_00: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y0)) & table.grad_mask;
			const g_idx_10: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y0)) & table.grad_mask;
			const g_idx_01: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y1)) & table.grad_mask;
			const g_idx_11: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y1)) & table.grad_mask;

			const g_x_00: f32 = table.grad_table[0][g_idx_00];
			const g_x_10: f32 = table.grad_table[0][g_idx_10];
			const g_x_01: f32 = table.grad_table[0][g_idx_01];
			const g_x_11: f32 = table.grad_table[0][g_idx_11];

			const g_y_00: f32 = table.grad_table[1][g_idx_00];
			const g_y_10: f32 = table.grad_table[1][g_idx_10];
			const g_y_01: f32 = table.grad_table[1][g_idx_01];
			const g_y_11: f32 = table.grad_table[1][g_idx_11];

			for (0..elem_count) |idx| {
				const x_rel: f32 = x_rel_cache[idx];
				const s_x: f32 = s_x_cache[idx];
				const x_rel_m1: f32 = x_rel - 1.0;

				const dx_00: f32 = g_x_00 * x_rel;
				const dx_10: f32 = g_x_10 * x_rel_m1;
				const dx_01: f32 = g_x_01 * x_rel;
				const dx_11: f32 = g_x_11 * x_rel_m1;

				s_x_cache_arr[idx] = s_x;
				i_x0_cache_arr[idx] = lerp_scalar(dx_00, dx_10, s_x);
				delta_i_x_cache_arr[idx] = lerp_scalar(dx_01 - dx_00, dx_11 - dx_10, s_x);
			}

			var y_idx: u64 = (min_dim - 1 - arr_world_off_y_u) & sc_m;
			var out_row_ptr: [*]f32 = out_buffer.ptr + arr_world_tile_x_u + (arr_world_tile_y_u << cs_l);

			for (0..min_dim) |_| {
				const y_rel: f32 = cached_values[y_idx];
				const s_y: f32 = cached_smoothed_values[y_idx];
				const y_rel_m1: f32 = y_rel - 1.0;

				const dy_00: f32 = g_y_00 * y_rel;
				const dy_10: f32 = g_y_10 * y_rel;
				const dy_01: f32 = g_y_01 * y_rel_m1;
				const dy_11: f32 = g_y_11 * y_rel_m1;

				const i_y0: f32 = @mulAdd(f32, s_y, dy_01 - dy_00, dy_00);
				const delta_i_y: f32 = @mulAdd(f32, s_y, (dy_11 - dy_01) - (dy_10 - dy_00), dy_10 - dy_00);

				for (0..elem_count) |idx| {
					const c_x: f32 = @mulAdd(f32, s_y, delta_i_x_cache_arr[idx], i_x0_cache_arr[idx]);
					out_row_ptr[idx] = @mulAdd(f32, s_x_cache_arr[idx], delta_i_y, i_y0 + c_x);
				}

				y_idx = (y_idx -% 1) & sc_m;
				out_row_ptr += cs_u;
			}
		}
	}
}
