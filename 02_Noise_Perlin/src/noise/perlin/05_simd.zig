const table = @import("../../core/f32/table.zig");
const vector_math = @import("../../core/f32/vector_math.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

const LANES: u8 = @as(u8, @intCast(vector_math.lanes_for(f32)));
const VecF = @Vector(LANES, f32);
const SIMD_ALIGNMENT: u29 = @as(u29, @intCast(vector_math.simd_vector_bytes()));
const VEC_ALIGN: u29 = @alignOf(VecF);

pub const RequiredAlignment: u29 = @max(VEC_ALIGN, SIMD_ALIGNMENT);
pub const sample_kind: mode_meta.SampleKind = .f32;

pub fn workspace_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
	const min_dim: u64 = @min(chunk_size, scale);
	const vec_count: u64 = min_dim / LANES;
	return @as(usize, @intCast(vec_count)) * @sizeOf(VecF) * 3;
}

comptime {
	if (@popCount(@as(u64, LANES)) != 1) {
		@compileError("O5 requires LANES to be a power of two");
	}
	if (@popCount(@as(u64, RequiredAlignment)) != 1) {
		@compileError("RequiredAlignment must be a non-zero power of two");
	}
}

inline fn lerp_vec(a: VecF, b: VecF, t: VecF) VecF {

	return (b - a) * t + a;
}

inline fn lerp_scalar(a: f32, b: f32, t: f32) f32 {
	return (b - a) * t + a;
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
			@compileError("O5 requires SCALE to be a power of two");
		}
		if ((@min(chunk_size, scale) % LANES) != 0) {
			@compileError("O5 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
		}
	}

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
	noalias cached_values: []const f32,
	noalias cached_smoothed_values: []const f32,
	world_x: i64,
	world_y: i64,
	noalias out_buffer: []f32,
) !void {
	// Verificar alineación de coordenadas mundiales para SIMD
	const lane_mask: u64 = LANES - 1; 
	const wx_u: u64 = @bitCast(world_x);
	const wy_u: u64 = @bitCast(world_y);

	if (((wx_u | wy_u) & lane_mask) != 0) {
			return error.WorldCoordinatesNotVectorAligned;
	}

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
	const vec_count: usize = comptime @as(usize, @intCast(@divExact(min_dim, LANES)));

	const x_rel_base = cached_values.ptr + arr_world_off_x_u;
	const s_x_base = cached_smoothed_values.ptr + arr_world_off_x_u;

	const x_rel_cache_vec: [*]const VecF = @ptrCast(@alignCast(x_rel_base));
	const s_x_cache_vec: [*]const VecF = @ptrCast(@alignCast(s_x_base));

	var s_x_cache_arr: [vec_count]VecF = undefined;
	var i_x0_cache_arr: [vec_count]VecF = undefined;
	var delta_i_x_cache_arr: [vec_count]VecF = undefined;

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

			const g_x_00: VecF = @splat(table.grad_table[0][g_idx_00]);
			const g_x_10: VecF = @splat(table.grad_table[0][g_idx_10]);
			const g_x_01: VecF = @splat(table.grad_table[0][g_idx_01]);
			const g_x_11: VecF = @splat(table.grad_table[0][g_idx_11]);

			const g_y_00: f32 = table.grad_table[1][g_idx_00];
			const g_y_10: f32 = table.grad_table[1][g_idx_10];
			const g_y_01: f32 = table.grad_table[1][g_idx_01];
			const g_y_11: f32 = table.grad_table[1][g_idx_11];

			const one: VecF = @splat(1.0);
			inline for (0..vec_count) |vec_idx| {
				const x_rel_vec: VecF = x_rel_cache_vec[vec_idx];
				const s_x_vec: VecF = s_x_cache_vec[vec_idx];

				const dx_00: VecF = g_x_00 * x_rel_vec;
				const dx_10: VecF = g_x_10 * (x_rel_vec - one);
				const dx_01: VecF = g_x_01 * x_rel_vec;
				const dx_11: VecF = g_x_11 * (x_rel_vec - one);

				s_x_cache_arr[vec_idx] = s_x_vec;
				i_x0_cache_arr[vec_idx] = lerp_vec(dx_00, dx_10, s_x_vec);
				delta_i_x_cache_arr[vec_idx] = lerp_vec(dx_01 - dx_00, dx_11 - dx_10, s_x_vec);
			}

			var y_idx: u64 = (min_dim - 1 - arr_world_off_y_u) & sc_m;
			var out_row_ptr: [*]f32 = out_buffer.ptr + arr_world_tile_x_u + (arr_world_tile_y_u << cs_l);

			for (0..min_dim) |_| {
				const y_rel: f32 = cached_values[y_idx];
				const y_rel_m1: f32 = y_rel - 1.0;
				const s_y: f32 = cached_smoothed_values[y_idx];

				const dy_00: f32 = g_y_00 * y_rel;
				const dy_01: f32 = g_y_01 * y_rel_m1;
				const dy_10: f32 = g_y_10 * y_rel;
				const dy_11: f32 = g_y_11 * y_rel_m1;

				const s_y_vec: VecF = @splat(s_y);
				const i_y0: VecF = @splat(lerp_scalar(dy_00, dy_01, s_y));
				const delta_i_y: VecF = @splat(lerp_scalar(dy_10 - dy_00, dy_11 - dy_01, s_y));

				const out_row_vec: [*]VecF = @as([*]VecF, @ptrCast(@alignCast(out_row_ptr)));

				inline for (0..vec_count) |vec_idx| {
					const c_x: VecF = i_x0_cache_arr[vec_idx] + (s_y_vec * delta_i_x_cache_arr[vec_idx]);
					const c_y: VecF = i_y0 + (s_x_cache_arr[vec_idx] * delta_i_y);
					out_row_vec[vec_idx] = c_x + c_y;
				}

				y_idx = (y_idx -% 1) & sc_m;
				out_row_ptr += cs_u;
			}
		}
	}
}
