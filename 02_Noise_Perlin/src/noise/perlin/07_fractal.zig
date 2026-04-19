const std = @import("std");

const table = @import("../../core/i16/table.zig");
const vector_math = @import("../../core/i16/vector_math.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

const LANES: u8 = @as(u8, @intCast(vector_math.lanes_for(i16)));
const VecI = @Vector(LANES, i16);
const SIMD_ALIGNMENT: u29 = @as(u29, @intCast(vector_math.simd_vector_bytes()));
const VEC_ALIGN: u29 = @alignOf(VecI);

const LACUNARITY_SHIFT: u6 = 1; // fixed lacunarity = 2
const PERSISTENCE_SHIFT: u6 = 1; // fixed persistence = 0.5

pub const RequiredAlignment: u29 = @max(VEC_ALIGN, SIMD_ALIGNMENT);
pub const sample_kind: mode_meta.SampleKind = .i16;

pub fn workspace_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
	const min_dim: u64 = @min(chunk_size, scale);
	const vec_count: u64 = min_dim / LANES;
	return @as(usize, @intCast(vec_count)) * @sizeOf(VecI) * 3;
}

comptime {
	if (@popCount(@as(u64, LANES)) != 1) {
		@compileError("O7 requires LANES to be a power of two");
	}
	if (@popCount(@as(u64, RequiredAlignment)) != 1) {
		@compileError("RequiredAlignment must be a non-zero power of two");
	}
}

inline fn mul_q15_scalar(a: i16, b: i16) i16 {
	const a32: i32 = @as(i32, a);
	const b32: i32 = @as(i32, b);
	return @as(i16, @intCast((a32 * b32) >> 15));
}

inline fn lerp_vec_q15(a: VecI, b: VecI, t: VecI) VecI {
	const diff: VecI = b - a;
	return vector_math.mul_q15_round(t, diff) + a;
}

inline fn lerp_scalar_q15(a: i16, b: i16, t: i16) i16 {
	const diff: i32 = @as(i32, b) - @as(i32, a);
	const t32: i32 = @as(i32, t);
	const mul_round: i16 = @as(i16, @intCast((t32 * diff) >> 15));
	return a + mul_round;
}

inline fn prepare_cached_values_for_scale(
	values_buf: []i16,
	smoothed_buf: []i16,
	comptime scale: u64,
) void {
	for (0..scale) |i| {
		values_buf[i] = @as(i16, @intCast(i)) << (15 - @ctz(scale));
		smoothed_buf[i] = @as(i16, @intFromFloat(
			@as(f32, @floatFromInt(0x7FFF)) * math.smooth_step(
				@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(scale))
			),
		));
	}
}

pub inline fn perlin_prepare_seed(seed: u64) u64 {
	return hash.custom_hash_init_v1(seed);
}

pub inline fn perlin_prepare_cached_values(
	values_buf: []i16,
	smoothed_buf: []i16,
	comptime chunk_size: u64,
	comptime scale: u64,
) void {
	comptime {
		if (@popCount(scale) != 1) {
			@compileError("O7 requires SCALE to be a power of two");
		}
		if ((@min(chunk_size, scale) % LANES) != 0) {
			@compileError("O7 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
		}
	}

	prepare_cached_values_for_scale(values_buf, smoothed_buf, scale);
}

inline fn scale_world_coord(coord: i64, shift: u6) i64 {
	const scaled_u: u64 = @as(u64, @bitCast(coord)) << shift;
	return @as(i64, @bitCast(scaled_u));
}

fn generate_octave_chunk2d(
	initialized_seed: u64,
	comptime chunk_size: u64,
	comptime scale: u64,
	cached_values: []const i16,
	cached_smoothed_values: []const i16,
	world_x: i64,
	world_y: i64,
	noalias out_buffer: []i16,
) !void {
	const lane_mask_u: u64 = @as(u64, LANES) - 1;
	if (((@as(u64, @bitCast(world_x)) & lane_mask_u) != 0) or ((@as(u64, @bitCast(world_y)) & lane_mask_u) != 0)) {
		return error.WorldCoordinatesNotVectorAligned;
	}

	const cs_u: u64 = chunk_size;
	const cs_l: u6 = @as(u6, @intCast(@ctz(cs_u)));

	const sc_u: u64 = scale;
	const sc_m: u64 = sc_u - 1;
	const sc_l: u6 = @as(u6, @intCast(@ctz(sc_u)));

	const grid_base_x: i64 = world_x >> sc_l;
	const grid_base_y: i64 = world_y >> sc_l;

	const grids_per_side: u64 = @max(cs_u >> sc_l, @as(u64, 1));
	const gps: usize = @as(usize, @intCast(grids_per_side + 1));

	const arr_world_off_x_u: u64 = @as(u64, @bitCast(world_x)) & sc_m;
	const arr_world_off_y_u: u64 = @as(u64, @bitCast(world_y)) & sc_m;

	const min_dim: u64 = comptime @min(chunk_size, scale);
	const vec_count: usize = comptime @as(usize, @intCast(@divExact(min_dim, LANES)));

	const x_rel_base = cached_values.ptr + arr_world_off_x_u;
	const s_x_base = cached_smoothed_values.ptr + arr_world_off_x_u;

	const x_rel_cache_vec: [*]const VecI = @ptrCast(@alignCast(x_rel_base));
	const s_x_cache_vec: [*]const VecI = @ptrCast(@alignCast(s_x_base));

	var s_x_cache_arr: [vec_count]VecI = undefined;
	var i_x0_cache_arr: [vec_count]VecI = undefined;
	var delta_i_x_cache_arr: [vec_count]VecI = undefined;

	for (0..(gps - 1)) |gy| {
		const noise_local_tile_y_u: u64 = (gps - 1) - gy - 1;
		const arr_world_tile_y_u: u64 = noise_local_tile_y_u << sc_l;

		for (0..(gps - 1)) |gx| {
			const arr_world_tile_x_u: u64 = gx << sc_l;
			const grid_x0: i64 = grid_base_x + @as(i64, @intCast(gx));
			const grid_y0: i64 = grid_base_y + @as(i64, @intCast(gy));
			const grid_x1: i64 = grid_x0 + 1;
			const grid_y1: i64 = grid_y0 + 1;

			const g_idx_00: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y0)) & table.grad_mask;
			const g_idx_10: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y0)) & table.grad_mask;
			const g_idx_01: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y1)) & table.grad_mask;
			const g_idx_11: u64 = hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y1)) & table.grad_mask;

			const g_x_00: VecI = @splat(table.grad_table[0][g_idx_00]);
			const g_x_10: VecI = @splat(table.grad_table[0][g_idx_10]);
			const g_x_01: VecI = @splat(table.grad_table[0][g_idx_01]);
			const g_x_11: VecI = @splat(table.grad_table[0][g_idx_11]);

			const g_y_00: i16 = table.grad_table[1][g_idx_00];
			const g_y_10: i16 = table.grad_table[1][g_idx_10];
			const g_y_01: i16 = table.grad_table[1][g_idx_01];
			const g_y_11: i16 = table.grad_table[1][g_idx_11];

			inline for (0..vec_count) |vec_idx| {
				const x_rel_vec: VecI = x_rel_cache_vec[vec_idx];
				const s_x_vec: VecI = s_x_cache_vec[vec_idx];
				const x_rel_m1: VecI = x_rel_vec - @as(VecI, @splat(0x7FFF));

				const dx_00 = vector_math.mul_q15_round(g_x_00, x_rel_vec);
				const dx_10 = vector_math.mul_q15_round(g_x_10, x_rel_m1);
				const dx_01 = vector_math.mul_q15_round(g_x_01, x_rel_vec);
				const dx_11 = vector_math.mul_q15_round(g_x_11, x_rel_m1);

				const i_x0 = lerp_vec_q15(dx_00, dx_10, s_x_vec);
				const delta_i_x = lerp_vec_q15(dx_01 - dx_00, dx_11 - dx_10, s_x_vec);

				s_x_cache_arr[vec_idx] = s_x_vec;
				i_x0_cache_arr[vec_idx] = i_x0;
				delta_i_x_cache_arr[vec_idx] = delta_i_x;
			}

			var y_idx: u64 = (min_dim - 1 - arr_world_off_y_u) & sc_m;
			var out_row_ptr: [*]i16 = out_buffer.ptr + arr_world_tile_x_u + (arr_world_tile_y_u << cs_l);

			for (0..min_dim) |_| {
				const y_rel: i16 = cached_values[y_idx];
				const s_y: i16 = cached_smoothed_values[y_idx];

				const y_rel_m1: i16 = y_rel - 0x7FFF;

				const dy_00 = mul_q15_scalar(g_y_00, y_rel);
				const dy_10 = mul_q15_scalar(g_y_10, y_rel);
				const dy_01 = mul_q15_scalar(g_y_01, y_rel_m1);
				const dy_11 = mul_q15_scalar(g_y_11, y_rel_m1);

				const i_y0_scalar = lerp_scalar_q15(dy_00, dy_01, s_y);
				const delta_i_y_scalar = lerp_scalar_q15(dy_10 - dy_00, dy_11 - dy_01, s_y);

				const s_y_vec: VecI = @splat(s_y);
				const i_y0: VecI = @splat(i_y0_scalar);
				const delta_i_y: VecI = @splat(delta_i_y_scalar);

				const out_row_vec: [*]VecI = @as([*]VecI, @ptrCast(@alignCast(out_row_ptr)));

				inline for (0..vec_count) |vec_idx| {
					const c_x = i_x0_cache_arr[vec_idx] + vector_math.mul_q15_round(s_y_vec, delta_i_x_cache_arr[vec_idx]);
					const c_y = i_y0 + vector_math.mul_q15_round(s_x_cache_arr[vec_idx], delta_i_y);

					out_row_vec[vec_idx] = c_x + c_y;
				}

				y_idx = (y_idx -% 1) & sc_m;
				out_row_ptr += cs_u;
			}
		}
	}
}

pub fn perlin_generate_chunk2d(
	seed: u64,
	comptime chunk_size: u64,
	comptime scale: u64,
	comptime octaves: u64,
	cached_values: []const i16,
	cached_smoothed_values: []const i16,
	world_x: i64,
	world_y: i64,
	noalias out_buffer: []i16,
) !void {
	comptime {
		if (octaves == 0) {
			@compileError("O7 requires OCTAVES to be >= 1");
		}
		if (@popCount(scale) != 1) {
			@compileError("O7 requires SCALE to be a power of two");
		}
		if ((@min(chunk_size, scale) % LANES) != 0) {
			@compileError("O7 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
		}

		const max_octaves_scale: u64 = @as(u64, @intCast(@ctz(scale))) + 1;
		if (octaves > max_octaves_scale) {
			@compileError("O7 OCTAVES exceeds SCALE support");
		}
		if (octaves > 32) {
			@compileError("O7 OCTAVES must be <= 32 for i32 shift-based persistence");
		}

		for (0..octaves) |octave_idx| {
			const octave_shift: u6 = @as(u6, @intCast(octave_idx * LACUNARITY_SHIFT));
			const octave_scale: u64 = scale >> octave_shift;
			if ((@min(chunk_size, octave_scale) % LANES) != 0) {
				@compileError("O7 requires every octave min(CHUNK_SIZE, SCALE_octave) to be a multiple of LANES");
			}
		}
	}

	const initialized_seed: u64 = hash.custom_hash_init_v1(seed);
	const sample_count: usize = comptime @as(usize, @intCast(chunk_size * chunk_size));
	var accum: [sample_count]i32 = [_]i32{0} ** sample_count;

	inline for (0..octaves) |octave_idx| {
		const octave_shift: u6 = comptime @as(u6, @intCast(octave_idx * LACUNARITY_SHIFT));
		const octave_scale: u64 = comptime scale >> octave_shift;
		const octave_world_x: i64 = scale_world_coord(world_x, octave_shift);
		const octave_world_y: i64 = scale_world_coord(world_y, octave_shift);

		if (comptime octave_idx == 0) {
			try generate_octave_chunk2d(
				initialized_seed,
				chunk_size,
				octave_scale,
				cached_values,
				cached_smoothed_values,
				octave_world_x,
				octave_world_y,
				out_buffer,
			);
		} else {
			const octave_scale_usize: usize = comptime @as(usize, @intCast(octave_scale));
			var octave_values: [octave_scale_usize]i16 align(RequiredAlignment) = undefined;
			var octave_smoothed: [octave_scale_usize]i16 align(RequiredAlignment) = undefined;

			prepare_cached_values_for_scale(
				octave_values[0..],
				octave_smoothed[0..],
				octave_scale,
			);

			try generate_octave_chunk2d(
				initialized_seed,
				chunk_size,
				octave_scale,
				octave_values[0..],
				octave_smoothed[0..],
				octave_world_x,
				octave_world_y,
				out_buffer,
			);
		}

		const amp_shift: u5 = comptime @as(u5, @intCast(octave_idx * PERSISTENCE_SHIFT));
		for (0..sample_count) |sample_idx| {
			const octave_sample: i32 = @as(i32, out_buffer[sample_idx]);
			const contribution: i32 = if (comptime amp_shift == 0)
				octave_sample
			else
				octave_sample >> amp_shift;
			accum[sample_idx] += contribution;
		}
	}

	for (0..sample_count) |sample_idx| {
		const clamped: i32 = std.math.clamp(
			accum[sample_idx],
			@as(i32, std.math.minInt(i16)),
			@as(i32, std.math.maxInt(i16)),
		);
		out_buffer[sample_idx] = @as(i16, @intCast(clamped));
	}
}
