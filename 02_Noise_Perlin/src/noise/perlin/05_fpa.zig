const hash = @import("../../core/shared/hash.zig");
const table = @import("../../core/i16/table.zig");
const types = @import("../../core/i16/types.zig");
const math = @import("../../core/shared/math.zig");
const vector_math = @import("../../core/i16/vector_math.zig");

const LANES: u8 = vector_math.q15_lanes;
const Vec_i = @Vector(LANES, i16);
const VEC_ALIGN: u29 = @alignOf(Vec_i);
pub const RequiredAlignment: u29 = VEC_ALIGN;

comptime {
  if (RequiredAlignment == 0 or (RequiredAlignment & (RequiredAlignment - 1)) != 0) {
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
  comptime seed: u64,
  comptime chunk_size: u64,
  comptime scale: u64,
  comptime octaves: u64,
	comptime persistence: f32,
  comptime lacunarity: f32,
) types.PerlinConfig {
  comptime {
    if (scale == 0 or (scale & (scale - 1)) != 0) {
      @compileError("O5 requires SCALE to be a non-zero power of two");
    }

    const min_dim = @min(chunk_size, scale);
    if ((min_dim % LANES) != 0) {
      @compileError("O5 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
    }
  }

  const sc_l: u6 = @as(u6, @intCast(@ctz(scale)));
  for (0..scale) |i| {
    const if32: i16 = @as(i16, @intCast(i)) << (15 - sc_l); // Escalado a Q0.15
    values_buf[i] = if32;
    smoothed_buf[i] = @as(i16, @intFromFloat(
      @as(f32, 0x7FFF) * math.smooth_step(@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(scale)))
    ));
  }

  return types.PerlinConfig{
    .seed = seed,
    .chunk_size = chunk_size,
    .scale = scale,
    .octaves = octaves,
    .persistence = persistence,
    .lacunarity = lacunarity,
    .cached_values = values_buf,
    .cached_smoothed_values = smoothed_buf,
  };
}

inline fn precompute_gradients(
  noise_grid_base_x_i: i64,
  noise_grid_base_y_i: i64,
  gps: usize,
  cfg: types.PerlinConfig,
  gc: [2][]i16,
) void {
  for (0..gps) |gy| {
    for (0..gps) |gx| {
      const noise_grid_x_i: i64 = noise_grid_base_x_i + @as(i64, @intCast(gx));
      const noise_grid_y_i: i64 = noise_grid_base_y_i + @as(i64, @intCast(gy));
      
      const u64_idx: u64 = hash.custom_hash(
        cfg.seed, 
        noise_grid_x_i, 
        noise_grid_y_i
      );

      gc[0][gy * gps + gx] = table.grad_soa[0][u64_idx & table.grad_mask];
      gc[1][gy * gps + gx] = table.grad_soa[1][u64_idx & table.grad_mask];
    }
  }
}

pub fn perlin_generate_chunk2d(
  cfg: types.PerlinConfig,
  chunk_x: i64,
  chunk_y: i64,
  out_buffer: []i16,
  gc: [2][]i16,
  scratch_allocator: anytype,
) void {
  _ = scratch_allocator;
  const cs_u: u64 = @intCast(cfg.chunk_size);
  const cs_i: i64 = @as(i64, @intCast(cfg.chunk_size));

  const sc_u: u64 = @intCast(cfg.scale);
  const sc_m: u64 = sc_u - 1;
  const sc_l: u6 = @as(u6, @intCast(@ctz(sc_u)));

  const arr_world_base_x_i: i64 = chunk_x * cs_i;
  const arr_world_base_y_i: i64 = chunk_y * cs_i;

  // gps = grids per chunk side (minimum 2 to cover cell corners)
  const gps: usize = @max(@as(u64, @intCast(cs_u >> sc_l)), 1) + 1;
  precompute_gradients(
    arr_world_base_x_i >> sc_l, 
    arr_world_base_y_i >> sc_l, 
    gps, 
    cfg, 
    gc
  );

  const arr_world_off_x_u: u64 = @as(u64, @bitCast(arr_world_base_x_i )) & sc_m;
  const arr_world_off_y_u: u64 = @as(u64, @bitCast(arr_world_base_y_i )) & sc_m;

  const q15_4_vec_i: Vec_i = @splat(@as(i16, 4)); // Para compensar gradientes a mitad de escala.
  const q15_one: Vec_i = @splat(@as(i16, 0x7FFF));

  const min_dim: u64 = @as(u64, @intCast(@min(cs_u, sc_u)));

  const values_base: [*]const i16 = cfg.cached_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
  const smooth_base: [*]const i16 = cfg.cached_smoothed_values.ptr + @as(u64, @intCast(arr_world_off_x_u));

  for (0..(gps - 1)) |gy| {
    const noise_local_tile_y_u: u64 = (gps - 1) - gy - 1;
    const arr_world_tile_y_u: u64 = noise_local_tile_y_u * sc_u;

    for (0..(gps - 1)) |gx| {
      const arr_world_tile_x_u: u64 = gx * sc_u;

      const g00x: Vec_i = @splat(gc[0][gy * gps + gx]);
      const g00y: Vec_i = @splat(gc[1][gy * gps + gx]);

      const g10x: Vec_i = @splat(gc[0][gy * gps + (gx + 1)]);
      const g10y: Vec_i = @splat(gc[1][gy * gps + (gx + 1)]);

      const g01x: Vec_i = @splat(gc[0][(gy + 1) * gps + gx]); 
      const g01y: Vec_i = @splat(gc[1][(gy + 1) * gps + gx]);

      const g11x: Vec_i = @splat(gc[0][(gy + 1) * gps + (gx + 1)]);
      const g11y: Vec_i = @splat(gc[1][(gy + 1) * gps + (gx + 1)]);

      for (0..min_dim) |ly| {
        const noise_local_y_idx_u: u64 = (min_dim - ly - 1 - arr_world_off_y_u) & sc_m;
        const noise_local_y_f: i16 = cfg.cached_values[noise_local_y_idx_u];
        const sy: i16 = cfg.cached_smoothed_values[noise_local_y_idx_u];

        const y_vec: Vec_i = @splat(noise_local_y_f);
        const y_minus_1_vec: Vec_i = @splat(noise_local_y_f - 0x7FFF);
        const sy_vec: Vec_i = @splat(sy);

        const matrix_offset: u64 = arr_world_tile_x_u + (arr_world_tile_y_u + ly) * cs_u;
        const out_row_ptr: [*]i16 = out_buffer.ptr + @as(u64, @intCast(matrix_offset));

        const g00y_vec: Vec_i = vector_math.mul_q15_round(g00y, y_vec);
        const g10y_vec: Vec_i = vector_math.mul_q15_round(g10y, y_vec);
        const g01y_vec: Vec_i = vector_math.mul_q15_round(g01y, y_minus_1_vec);
        const g11y_vec: Vec_i = vector_math.mul_q15_round(g11y, y_minus_1_vec);

        var lx: u64 = 0;
        while (lx < min_dim) : (lx += LANES) {
          const x_vec: Vec_i = load_vec_aligned(values_base, lx);
          const sx_vec: Vec_i = load_vec_aligned(smooth_base, lx);

          const x_minus_1_vec: Vec_i = x_vec - q15_one;

          const d00: Vec_i = vector_math.mul_q15_round(g00x, x_vec) + g00y_vec;
          const d10: Vec_i = vector_math.mul_q15_round(g10x, x_minus_1_vec) + g10y_vec;
          const d01: Vec_i = vector_math.mul_q15_round(g01x, x_vec) + g01y_vec;
          const d11: Vec_i = vector_math.mul_q15_round(g11x, x_minus_1_vec) + g11y_vec;

          const interp0: Vec_i = vector_math.mul_q15_round(sx_vec, d10 - d00) + d00;
          const interp1: Vec_i = vector_math.mul_q15_round(sx_vec, d11 - d01) + d01;
          const value_vec: Vec_i = vector_math.mul_q15_round(sy_vec, interp1 - interp0) + interp0;

          store_vec_aligned(out_row_ptr, lx, value_vec * q15_4_vec_i);
        }
      }
    }
  }
}