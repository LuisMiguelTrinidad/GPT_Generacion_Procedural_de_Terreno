const std = @import("std");

const table = @import("../../core/f32/table.zig");
const types = @import("../../core/f32/types.zig");
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
pub const grad_layout: mode_meta.GradLayout = .soa;
comptime {
  if (@popCount(RequiredAlignment) != 1) {
    @compileError("RequiredAlignment must be a power of two");
  }
}

inline fn load_vec8_aligned(base: [*]const f32, idx: usize) VecF {
  return @as(*const VecF, @ptrCast(@alignCast(base + idx))).*;
}

inline fn store_vec8_aligned(base: [*]f32, idx: usize, v: VecF) void {
  @as(*VecF, @ptrCast(@alignCast(base + idx))).* = v;
}

pub fn perlin_init_config(
  values_buf: []f32,
  smoothed_buf: []f32,
  seed: u64,
  comptime chunk_size: u64,
  comptime scale: u64,
  comptime octaves: u64,
	comptime persistence: f32,
  comptime lacunarity: f32,
) types.PerlinConfig {

  comptime {
    if ((@popCount(scale) != 1)) {
      @compileError("O4 requires SCALE to be a power of two");
    }
    if (@min(chunk_size, scale) % LANES != 0) {
      @compileError("O4 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
    }
  }

  for (0..scale) |i| {
    const if32: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(scale));
    values_buf[i] = if32;
    smoothed_buf[i] = math.smooth_step(if32);
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

inline fn precompute_gradients(
  noise_grid_base_x_i: i64,
  noise_grid_base_y_i: i64,
  gps: usize,
  cfg: types.PerlinConfig,
  gc: [2][]f32,
) void {  for (0..gps) |gy| {
    for (0..gps) |gx| {
      const u64_idx: u64 = hash.custom_hash_v1_no_init(
        cfg.seed, 
        @as(u64, @bitCast(noise_grid_base_x_i)) + gx,
        @as(u64, @bitCast(noise_grid_base_y_i)) + gy
      ) & table.grad_mask;
      gc[0][gy * gps + gx] = table.grad_soa[0][u64_idx];
      gc[1][gy * gps + gx] = table.grad_soa[1][u64_idx];
    }
  }
}

pub fn perlin_generate_chunk2d(
  cfg: types.PerlinConfig,
  chunk_x: i64,
  chunk_y: i64,
  out_buffer: []f32,
  gc: [2][]f32,
  scratch_allocator: std.mem.Allocator,
) !void {
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

  const one_vec: VecF = @splat(1.0);
  const min_dim: u64 = @as(u64, @intCast(@min(cs_u, sc_u)));
  const vec_count: u64 = min_dim / LANES;

  const values_base: [*]const f32 = cfg.cached_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
  const smooth_base: [*]const f32 = cfg.cached_smoothed_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
  const values_cache_vec: [*]const VecF = @as([*]const VecF, @ptrCast(@alignCast(values_base)));
  const smooth_cache_vec: [*]const VecF = @as([*]const VecF, @ptrCast(@alignCast(smooth_base)));

  for (0..(gps - 1)) |gy| {
    const noise_local_tile_y_u: u64 = (gps - 1) - gy - 1;
    const arr_world_tile_y_u: u64 = noise_local_tile_y_u * sc_u;

    for (0..(gps - 1)) |gx| {
      const arr_world_tile_x_u: u64 = gx * sc_u;

      const idx00 = gy * gps + gx;
      const idx10 = idx00 + 1;
      const idx01 = (gy + 1) * gps + gx;
      const idx11 = idx01 + 1;

      const g00x: VecF = @splat(gc[0][idx00]);
      const g00y: VecF = @splat(gc[1][idx00]);

      const g10x: VecF = @splat(gc[0][idx10]);
      const g10y: VecF = @splat(gc[1][idx10]);

      const g01x: VecF = @splat(gc[0][idx01]);
      const g01y: VecF = @splat(gc[1][idx01]);

      const g11x: VecF = @splat(gc[0][idx11]);
      const g11y: VecF = @splat(gc[1][idx11]);

      for (0..min_dim) |ly| {
        const noise_local_y_idx_u: u64 = (min_dim - ly - 1 - arr_world_off_y_u) & sc_m;
        const noise_local_y_f: f32 = cfg.cached_values[noise_local_y_idx_u];
        const sy: f32 = cfg.cached_smoothed_values[noise_local_y_idx_u];

        const y_vec: VecF = @splat(noise_local_y_f);
        const y_minus_1_vec: VecF = @splat(noise_local_y_f - 1.0);
        const sy_vec: VecF = @splat(sy);

        const matrix_offset: u64 = arr_world_tile_x_u + (arr_world_tile_y_u + ly) * cs_u;
        const out_row_ptr: [*]f32 = out_buffer.ptr + @as(u64, @intCast(matrix_offset));
        const out_row_vec: [*]VecF = @as([*]VecF, @ptrCast(@alignCast(out_row_ptr)));

        const g00y_vec: VecF = g00y * y_vec;
        const g10y_vec: VecF = g10y * y_vec;
        const g01y_vec: VecF = g01y * y_minus_1_vec;
        const g11y_vec: VecF = g11y * y_minus_1_vec;

        for(0..vec_count) |vec_idx| {
          const x_vec: VecF = values_cache_vec[vec_idx];
          const sx_vec: VecF = smooth_cache_vec[vec_idx];

          const x_minus_1_vec: VecF = x_vec - one_vec;

          const d00: VecF = @mulAdd(VecF, g00x, x_vec, g00y_vec);
          const d10: VecF = @mulAdd(VecF, g10x, x_minus_1_vec, g10y_vec);
          const d01: VecF = @mulAdd(VecF, g01x, x_vec, g01y_vec);
          const d11: VecF = @mulAdd(VecF, g11x, x_minus_1_vec, g11y_vec);

          const interp0: VecF = @mulAdd(VecF, sx_vec, d10 - d00, d00);
          const interp1: VecF = @mulAdd(VecF, sx_vec, d11 - d01, d01);
          const value_vec: VecF = @mulAdd(VecF, sy_vec, interp1 - interp0, interp0);

          out_row_vec[vec_idx] = value_vec;
        }
      }
    }
  }
}