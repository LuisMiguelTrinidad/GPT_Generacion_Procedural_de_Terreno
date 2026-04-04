const table = @import("../../core/i16/table.zig");
const types = @import("../../core/i16/types.zig");
const vector_math = @import("../../core/i16/vector_math.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

const LANES: u8 = vector_math.q15_lanes;
const Vec_i = @Vector(LANES, i16);
const VEC_ALIGN: u29 = @alignOf(Vec_i);
pub const RequiredAlignment: u29 = VEC_ALIGN;
pub const sample_kind: mode_meta.SampleKind = .i16;

const Q15_ONE: i16 = 0x7FFF;
const VEC_Q15_ONE: Vec_i = @splat(Q15_ONE);

comptime {
  if (@popCount(@as(u64, @alignOf(Vec_i))) != 1) {
    @compileError("RequiredAlignment must be a non-zero power of two");
  }
}

inline fn load_vec_aligned(base: [*]const i16, idx: usize) Vec_i {
  return @as(*const Vec_i, @ptrCast(@alignCast(base + idx))).*;
}

inline fn store_vec_aligned(base: [*]i16, idx: usize, v: Vec_i) void {
  @as(*Vec_i, @ptrCast(@alignCast(base + idx))).* = v;
}

pub fn perlin_init_config(
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
    if (@popCount(scale) != 1) {
      @compileError("O5 requires SCALE to be a power of two");
    }

    if ((@min(chunk_size, scale) % LANES) != 0) {
      @compileError("O5 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
    }
  }

  const sc_l: u6 = @as(u6, @intCast(@ctz(scale)));
  for (0..scale) |i| {
    values_buf[i] = @as(i16, @intCast(i)) << (15 - sc_l); // Escalado a Q0.15
    smoothed_buf[i] = @as(i16, @intFromFloat(
      @as(f32, @floatFromInt(Q15_ONE)) * math.smooth_step(
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
  chunk_x: i64,
  chunk_y: i64,
  out_buffer: []i16,
) !void {
  const cs_u: u64 = @intCast(cfg.chunk_size);
  const cs_i: i64 = @as(i64, @intCast(cfg.chunk_size));
  const cs_l: u6 = @as(u6, @intCast(@ctz(cs_u)));

  const sc_u: u64 = @intCast(cfg.scale);
  const sc_m: u64 = sc_u - 1;
  const sc_l: u6 = @as(u6, @intCast(@ctz(sc_u)));

  const arr_world_base_x_i: i64 = chunk_x * cs_i;
  const arr_world_base_y_i: i64 = chunk_y * cs_i;

  const noise_grid_base_x_i: i64 = arr_world_base_x_i >> sc_l;
  const noise_grid_base_y_i: i64 = arr_world_base_y_i >> sc_l;

  // gps = grids per chunk side (minimum 2 to cover cell corners)
  const gps: usize = @max(@as(u64, @intCast(cs_u >> sc_l)), 1) + 1;

  const arr_world_off_x_u: u64 = @as(u64, @bitCast(arr_world_base_x_i )) & sc_m;
  const arr_world_off_y_u: u64 = @as(u64, @bitCast(arr_world_base_y_i )) & sc_m;

  const min_dim: u64 = @as(u64, @intCast(@min(cs_u, sc_u)));
  const vec_count: u64 = min_dim / LANES;

  const values_base: [*]const i16 = cfg.cached_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
  const smooth_base: [*]const i16 = cfg.cached_smoothed_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
  const values_cache_vec: [*]const Vec_i = @as([*]const Vec_i, @ptrCast(@alignCast(values_base)));
  const smooth_cache_vec: [*]const Vec_i = @as([*]const Vec_i, @ptrCast(@alignCast(smooth_base)));

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

      const g00x: Vec_i = @splat(table.grad_soa[0][g00_idx]);
      const g00y: Vec_i = @splat(table.grad_soa[1][g00_idx]);

      const g10x: Vec_i = @splat(table.grad_soa[0][g10_idx]);
      const g10y: Vec_i = @splat(table.grad_soa[1][g10_idx]);

      const g01x: Vec_i = @splat(table.grad_soa[0][g01_idx]);
      const g01y: Vec_i = @splat(table.grad_soa[1][g01_idx]);

      const g11x: Vec_i = @splat(table.grad_soa[0][g11_idx]);
      const g11y: Vec_i = @splat(table.grad_soa[1][g11_idx]);

      for (0..min_dim) |ly| {
        const noise_local_y_idx_u: u64 = (min_dim - ly - 1 - arr_world_off_y_u) & sc_m;
        const noise_local_y_f: i16 = cfg.cached_values[noise_local_y_idx_u];
        const sy: i16 = cfg.cached_smoothed_values[noise_local_y_idx_u];

        const y_vec: Vec_i = @splat(noise_local_y_f);
        const y_minus_1_vec: Vec_i = @splat(noise_local_y_f - Q15_ONE);
        const sy_vec: Vec_i = @splat(sy);

        const matrix_offset: u64 = arr_world_tile_x_u + ((arr_world_tile_y_u + ly) << cs_l);
        const out_row_ptr: [*]i16 = out_buffer.ptr + @as(u64, @intCast(matrix_offset));
        const out_row_vec: [*]Vec_i = @as([*]Vec_i, @ptrCast(@alignCast(out_row_ptr)));

        const g00y_vec: Vec_i = vector_math.mul_q15_round(g00y, y_vec);
        const g10y_vec: Vec_i = vector_math.mul_q15_round(g10y, y_vec);
        const g01y_vec: Vec_i = vector_math.mul_q15_round(g01y, y_minus_1_vec);
        const g11y_vec: Vec_i = vector_math.mul_q15_round(g11y, y_minus_1_vec);


        for(0..vec_count) |vec_idx| {
          const x_vec: Vec_i = values_cache_vec[vec_idx];
          const sx_vec: Vec_i = smooth_cache_vec[vec_idx];

          const x_minus_1_vec: Vec_i = x_vec - @as(Vec_i, @splat(0x7FFF)); // x - 1.0 en Q15

          const d00: Vec_i = vector_math.mul_q15_round(g00x, x_vec) + g00y_vec;
          const d10: Vec_i = vector_math.mul_q15_round(g10x, x_minus_1_vec) + g10y_vec;
          const d01: Vec_i = vector_math.mul_q15_round(g01x, x_vec) + g01y_vec;
          const d11: Vec_i = vector_math.mul_q15_round(g11x, x_minus_1_vec) + g11y_vec;

          const interp0: Vec_i = vector_math.mul_q15_round(sx_vec, d10 - d00) + d00;
          const interp1: Vec_i = vector_math.mul_q15_round(sx_vec, d11 - d01) + d01;

          out_row_vec[vec_idx] = vector_math.mul_q15_round(sy_vec, interp1 - interp0) + interp0;
        }
      }
    }
  }
}