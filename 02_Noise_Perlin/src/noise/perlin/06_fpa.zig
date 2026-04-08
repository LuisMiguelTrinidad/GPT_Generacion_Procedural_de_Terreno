const table = @import("../../core/i16/table.zig");
const types = @import("../../core/i16/types.zig");
const vector_math = @import("../../core/i16/vector_math.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

const LANES: u8 = @as(u8, @intCast(vector_math.lanes_for(i16)));
const VecI = @Vector(LANES, i16);
const SIMD_ALIGNMENT: u29 = @as(u29, @intCast(vector_math.simd_vector_bytes()));
const VEC_ALIGN: u29 = @alignOf(VecI);

pub const RequiredAlignment: u29 = @max(VEC_ALIGN, SIMD_ALIGNMENT);
pub const sample_kind: mode_meta.SampleKind = .i16;

pub fn workspace_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
	const min_dim: u64 = @min(chunk_size, scale);
	const vec_count: u64 = min_dim / LANES;
	return @as(usize, @intCast(vec_count)) * @sizeOf(VecI) * 3;
}

comptime {
	if (@popCount(@as(u64, LANES)) != 1) {
		@compileError("O6 requires LANES to be a power of two");
	}
	if (@popCount(@as(u64, RequiredAlignment)) != 1) {
		@compileError("RequiredAlignment must be a non-zero power of two");
	}
}

// Scalar Q0.15 multiply helper.
inline fn mul_q15_scalar(a: i16, b: i16) i16 {
	const a32: i32 = @as(i32, a);
	const b32: i32 = @as(i32, b);
	return @as(i16, @intCast((a32 * b32) >> 15));
}

inline fn lerp_vec_q15(a: VecI, b: VecI, t: VecI) VecI {
	const diff: VecI = b - a;
	return vector_math.mul_q15_round(t, diff) + a;
}

// Asumiendo que mul_q15_round suma 0x4000 para redondear a la fracción más cercana.
// Ajusta el '+ 0x4000' si tu vector_math usa una lógica de truncamiento distinta.
inline fn lerp_scalar_q15(a: i16, b: i16, t: i16) i16 {
    const diff: i32 = @as(i32, b) - @as(i32, a);
    const t32: i32 = @as(i32, t);
    const mul_round = @as(i16, @intCast((t32 * diff) >> 15));
    return a + mul_round;
}

inline fn fill_x_cache(
  sx_cache: [*]VecI,
  i_x0_cache: [*]VecI,
  delta_ix_cache: [*]VecI,
  comptime vec_count: usize,
  values_cache_vec: [*]const VecI,
  smooth_cache_vec: [*]const VecI,
  g00x: VecI,
  g10x: VecI,
  g01x: VecI,
  g11x: VecI,
) void {
  inline for (0..vec_count) |vec_idx| {
    const x_vec: VecI = values_cache_vec[vec_idx];
    const sx_vec: VecI = smooth_cache_vec[vec_idx];
    const x_m1: VecI = x_vec - @as(VecI, @splat(0x7FFF));

    const dx00 = vector_math.mul_q15_round(g00x, x_vec);
    const dx10 = vector_math.mul_q15_round(g10x, x_m1);
    const dx01 = vector_math.mul_q15_round(g01x, x_vec);
    const dx11 = vector_math.mul_q15_round(g11x, x_m1);

    // Aplicamos la misma propiedad matemática a los vectores:
    // lerp(dx01, dx11, sx) - lerp(dx00, dx10, sx) == lerp(dx01 - dx00, dx11 - dx10, sx)
    const i_x0 = lerp_vec_q15(dx00, dx10, sx_vec);
    const delta_ix = lerp_vec_q15(dx01 - dx00, dx11 - dx10, sx_vec);

    sx_cache[vec_idx] = sx_vec;
    i_x0_cache[vec_idx] = i_x0;
    delta_ix_cache[vec_idx] = delta_ix; // Guardamos directamente el resultado
  }
}

pub inline fn perlin_init_config(
	values_buf: []i16,
	smoothed_buf: []i16,
	seed: u64,
	comptime chunk_size: u64,
	comptime scale: u64,
	comptime octaves: u64,
	comptime persistence: f32,
	comptime lacunarity: f32,
) types.PerlinConfig {
	comptime {
		if ((@popCount(scale) != 1)) {
			@compileError("O6 requires SCALE to be a power of two");
		}
		if ((@min(chunk_size, scale) % LANES) != 0) {
			@compileError("O6 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
		}
	}

	for (0..scale) |i| {
		values_buf[i] = @as(i16, @intCast(i)) << (15 - @ctz(scale));
		smoothed_buf[i] = @as(i16, @intFromFloat(
			@as(f32, @floatFromInt(0x7FFF)) * math.smooth_step(
				@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(scale))
			)
		));
	}

	return types.PerlinConfig{
		.seed = hash.custom_hash_init_v1(seed),
		.chunk_size = chunk_size,
		.scale = scale,
		.octaves = octaves,
		.persistence = persistence,
		.lacunarity = lacunarity,
		.cached_values = values_buf,
		.cached_smoothed_values = smoothed_buf,
	};
}

pub fn perlin_generate_chunk2d(
	cfg: types.PerlinConfig,
	world_x: i64,
	world_y: i64,
	noalias out_buffer: []i16,
	comptime chunk_size: u64,
	comptime scale: u64,
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

	const arr_world_base_x_i: i64 = world_x;
	const arr_world_base_y_i: i64 = world_y;
	const noise_grid_base_x_i: i64 = arr_world_base_x_i >> sc_l;
	const noise_grid_base_y_i: i64 = arr_world_base_y_i >> sc_l;

	const grids_per_side: u64 = @max(cs_u >> sc_l, @as(u64, 1));
	const gps: usize = @as(usize, @intCast(grids_per_side + 1));

	const arr_world_off_x_u: u64 = @as(u64, @bitCast(arr_world_base_x_i)) & sc_m;
	const arr_world_off_y_u: u64 = @as(u64, @bitCast(arr_world_base_y_i)) & sc_m;

	const min_dim: u64 = comptime @min(chunk_size, scale);
  const vec_count: usize = comptime @as(usize, @intCast(@divExact(min_dim, LANES)));

	const values_base: [*]const i16 = cfg.cached_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
	const smooth_base: [*]const i16 = cfg.cached_smoothed_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
	const values_cache_vec: [*]const VecI = @as([*]const VecI, @ptrCast(@alignCast(values_base)));
	const smooth_cache_vec: [*]const VecI = @as([*]const VecI, @ptrCast(@alignCast(smooth_base)));

	var sx_cache_arr: [vec_count]VecI = undefined;
	var i_x0_cache_arr: [vec_count]VecI = undefined;
	var delta_ix_cache_arr: [vec_count]VecI = undefined;

	for (0..(gps - 1)) |gy| {
		const noise_local_tile_y_u: u64 = (gps - 1) - gy - 1;
		const arr_world_tile_y_u: u64 = noise_local_tile_y_u << sc_l;

		for (0..(gps - 1)) |gx| {
			const arr_world_tile_x_u: u64 = gx << sc_l;
			const noise_grid_x0_i: i64 = noise_grid_base_x_i + @as(i64, @intCast(gx));
			const noise_grid_y0_i: i64 = noise_grid_base_y_i + @as(i64, @intCast(gy));
			const noise_grid_x1_i: i64 = noise_grid_x0_i + 1;
			const noise_grid_y1_i: i64 = noise_grid_y0_i + 1;

			const g00_idx: u64 = hash.custom_hash_v1_no_init(cfg.seed, @bitCast(noise_grid_x0_i), @bitCast(noise_grid_y0_i)) & table.grad_mask;
			const g10_idx: u64 = hash.custom_hash_v1_no_init(cfg.seed, @bitCast(noise_grid_x1_i), @bitCast(noise_grid_y0_i)) & table.grad_mask;
			const g01_idx: u64 = hash.custom_hash_v1_no_init(cfg.seed, @bitCast(noise_grid_x0_i), @bitCast(noise_grid_y1_i)) & table.grad_mask;
			const g11_idx: u64 = hash.custom_hash_v1_no_init(cfg.seed, @bitCast(noise_grid_x1_i), @bitCast(noise_grid_y1_i)) & table.grad_mask;

			const g00x: VecI = @splat(table.grad_table[0][g00_idx]);
			const g10x: VecI = @splat(table.grad_table[0][g10_idx]);
			const g01x: VecI = @splat(table.grad_table[0][g01_idx]);
			const g11x: VecI = @splat(table.grad_table[0][g11_idx]);

			const g00y_s: i16 = table.grad_table[1][g00_idx];
			const g10y_s: i16 = table.grad_table[1][g10_idx];
			const g01y_s: i16 = table.grad_table[1][g01_idx];
			const g11y_s: i16 = table.grad_table[1][g11_idx];

			fill_x_cache(
				&sx_cache_arr,
				&i_x0_cache_arr,
				&delta_ix_cache_arr,
				vec_count,
				values_cache_vec,
				smooth_cache_vec,
				g00x,
				g10x,
				g01x,
				g11x,
			);

			var y_idx: u64 = (min_dim - 1 - arr_world_off_y_u) & sc_m;
			var out_row_ptr: [*]i16 = out_buffer.ptr + arr_world_tile_x_u + (arr_world_tile_y_u << cs_l);

			for (0..min_dim) |_| {
				const y_rel: i16 = cfg.cached_values[y_idx];
				const sy_ly: i16 = cfg.cached_smoothed_values[y_idx];

				const y_rel_m1: i16 = y_rel - 0x7FFF;

				const dy00 = mul_q15_scalar(g00y_s, y_rel);
        const dy10 = mul_q15_scalar(g10y_s, y_rel);
        const dy01 = mul_q15_scalar(g01y_s, y_rel_m1);
        const dy11 = mul_q15_scalar(g11y_s, y_rel_m1);

        const i_y0_s = lerp_scalar_q15(dy00, dy01, sy_ly);
        const delta_iy_s = lerp_scalar_q15(dy10 - dy00, dy11 - dy01, sy_ly);

        const y_sy: VecI = @splat(sy_ly);
        const i_y0: VecI = @splat(i_y0_s);
        const delta_iy: VecI = @splat(delta_iy_s);

        const out_row_vec: [*]VecI = @as([*]VecI, @ptrCast(@alignCast(out_row_ptr)));

        inline for (0..vec_count) |vec_idx| {
          const term_x = i_x0_cache_arr[vec_idx] + vector_math.mul_q15_round(y_sy, delta_ix_cache_arr[vec_idx]);
          const term_y = i_y0 + vector_math.mul_q15_round(sx_cache_arr[vec_idx], delta_iy);

          out_row_vec[vec_idx] = term_y + term_x;
        }

        y_idx = (y_idx -% 1) & sc_m;
        out_row_ptr += cs_u;
			}
		}
	}
}