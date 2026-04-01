const std = @import("std");

const table = @import("../../core/i16/table.zig");
const types = @import("../../core/i16/types.zig");
const vector_math = @import("../../core/i16/vector_math.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

const Vec_i = @Vector(vector_math.q15_lanes, i16);

pub const RequiredAlignment: u29 = @alignOf(Vec_i);
pub const WorkspaceAlignment: comptime_int = RequiredAlignment;
pub const sample_kind: mode_meta.SampleKind = .i16;
pub const grad_layout: mode_meta.GradLayout = .soa;

const XState = struct {
  sx: Vec_i,
	dot_x_00: Vec_i,
	dot_x_10: Vec_i,
	dot_x_01: Vec_i,
	dot_x_11: Vec_i,
};

const YState = struct {
  sy: [UNROLL_FACTOR]Vec_i,
  dot_y_00: [UNROLL_FACTOR]Vec_i,
	dot_y_10: [UNROLL_FACTOR]Vec_i,
	dot_y_01: [UNROLL_FACTOR]Vec_i,
	dot_y_11: [UNROLL_FACTOR]Vec_i,
  out_ptrs: [UNROLL_FACTOR][*]Vec_i,
};

pub fn workspace_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
  const min_dim: u64 = @min(chunk_size, scale);
  const vec_count: u64 = min_dim / vector_math.q15_lanes;
  return @as(usize, @intCast(vec_count)) * @sizeOf(XState);
}

// --- CONSTANTES GLOBALES INVARIANTES ---
const UNROLL_FACTOR: u8 = 4;
const Q15_ONE: i16 = 0x7FFF;
const VEC_Q15_ONE: Vec_i = @splat(Q15_ONE);
const VEC_Q15_FOUR: Vec_i = @splat(4);

comptime {
  if (@popCount(@as(u64, @alignOf(Vec_i))) != 1) {
    @compileError("RequiredAlignment must be a non-zero power of two");
  }
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
    if ((@popCount(scale) != 1)) {
      @compileError("O6 requires SCALE to be a power of two");
    }
    if ((@min(chunk_size, scale) % vector_math.q15_lanes) != 0) {
      @compileError("O6 requires min(CHUNK_SIZE, SCALE) to be a multiple of LANES");
    }
    if ((@min(chunk_size, scale) % UNROLL_FACTOR) != 0) {
      @compileError("O6 requires min(CHUNK_SIZE, SCALE) to be a multiple of UNROLL_FACTOR");
    }
  }

  for (0..scale) |i| {
    values_buf[i] = @as(i16, @intCast(i)) << (15 - @ctz(scale)); // Escalado a Q0.15
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

inline fn precompute_gradients(
  noise_grid_base_x_i: i64,
  noise_grid_base_y_i: i64,
  gps: usize,
  cfg: types.PerlinConfig,
  gc: [2][]i16,
) void {
  for (0..gps) |gy| {
    for (0..gps) |gx| {
      const u64_idx: u64 = hash.custom_hash_v1_no_init(
        cfg.seed, 
        @as(u64, @bitCast(noise_grid_base_x_i)) + gx,
        @as(u64, @bitCast(noise_grid_base_y_i)) + gy
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
  scratch_allocator: std.mem.Allocator,
) !void {
  const cs_u: u64 = @intCast(cfg.chunk_size);

  const sc_u: u64 = @intCast(cfg.scale);
  const sc_m: u64 = sc_u - 1;
  const sc_l: u6 = @as(u6, @intCast(@ctz(sc_u)));

  const arr_world_base_x_i: i64 = chunk_x * @as(i64, @intCast(cs_u));
  const arr_world_base_y_i: i64 = chunk_y * @as(i64, @intCast(cs_u));

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

  const min_dim: u64 = @as(u64, @intCast(@min(cs_u, sc_u)));

  const values_base: [*]const i16 = cfg.cached_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
  const smooth_base: [*]const i16 = cfg.cached_smoothed_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
  const values_cache_vec: [*]const Vec_i = @as([*]const Vec_i, @ptrCast(@alignCast(values_base)));
  const smooth_cache_vec: [*]const Vec_i = @as([*]const Vec_i, @ptrCast(@alignCast(smooth_base)));

  const vec_count: u64 = min_dim / vector_math.q15_lanes;
  
  const x_cache = try scratch_allocator.alloc(XState, vec_count);
  defer scratch_allocator.free(x_cache);
  
  for (0..(gps - 1)) |gy| {
    const noise_local_tile_y_u: u64 = (gps - 1) - gy - 1;
    const arr_world_tile_y_u: u64 = noise_local_tile_y_u * sc_u;

    for (0..(gps - 1)) |gx| {
      const arr_world_tile_x_u: u64 = gx * sc_u;

      const idx00 = gy * gps + gx;
      const idx10 = idx00 + 1;
      const idx01 = (gy + 1) * gps + gx;
      const idx11 = idx01 + 1;

      const g00x: Vec_i = @splat(gc[0][idx00]);
      const g00y: Vec_i = @splat(gc[1][idx00]);

      const g10x: Vec_i = @splat(gc[0][idx10]);
      const g10y: Vec_i = @splat(gc[1][idx10]);

      const g01x: Vec_i = @splat(gc[0][idx01]);
      const g01y: Vec_i = @splat(gc[1][idx01]);

      const g11x: Vec_i = @splat(gc[0][idx11]);
      const g11y: Vec_i = @splat(gc[1][idx11]);

      for(0..vec_count) |vec_idx| {
        const x_vec: Vec_i = values_cache_vec[vec_idx];
        const sx_vec: Vec_i = smooth_cache_vec[vec_idx];
        
        const x_m1: Vec_i = x_vec - VEC_Q15_ONE;

        // Se sobrescribe el estado del caché en cada iteración del tile (gx, gy)
        x_cache[vec_idx] = .{
          .sx = sx_vec,
          .dot_x_00 = vector_math.mul_q15_round(g00x, x_vec),
					.dot_x_10 = vector_math.mul_q15_round(g10x, x_m1),
					.dot_x_01 = vector_math.mul_q15_round(g01x, x_vec),
					.dot_x_11 = vector_math.mul_q15_round(g11x, x_m1),
        };
      }

      var ly: u64 = 0;
      while (ly < min_dim) : (ly += UNROLL_FACTOR) {

        // 1. Preparar estado Y para cada fila del bloque.
        // Se agrupa en un struct (SoA) para reducir la presión de registros
        // al compartir las componentes Y interpoladas en las columnas X.
        var y_state: YState = undefined;
        for (0..UNROLL_FACTOR) |r| {
          const y_idx: u64 = (min_dim - (ly + r) - 1 - arr_world_off_y_u) & sc_m;
          const yf: i16 = cfg.cached_values[y_idx];
          const y_v: Vec_i = @splat(yf);
          const y_m1: Vec_i = @splat(yf - Q15_ONE);

          y_state.sy[r] = @splat(cfg.cached_smoothed_values[y_idx]);
          
          y_state.dot_y_00[r] = vector_math.mul_q15_round(g00y, y_v);
          y_state.dot_y_10[r] = vector_math.mul_q15_round(g10y, y_v);
          y_state.dot_y_01[r] = vector_math.mul_q15_round(g01y, y_m1);
          y_state.dot_y_11[r] = vector_math.mul_q15_round(g11y, y_m1);
        
          const out_row_ptr: [*]i16 = out_buffer.ptr + arr_world_tile_x_u + (arr_world_tile_y_u + ly + r) * cs_u;
          y_state.out_ptrs[r] = @as([*]Vec_i, @ptrCast(@alignCast(out_row_ptr)));
        }

				// 2. Bucle X: productos X-gradiente compartidos entre las UNROLL filas
				for (0..UNROLL_FACTOR) |r| {
					const sy_r = y_state.sy[r];

					const dy00 = y_state.dot_y_00[r];
					const dy10 = y_state.dot_y_10[r];
					const dy01 = y_state.dot_y_01[r];
					const dy11 = y_state.dot_y_11[r];

					const out_ptr = y_state.out_ptrs[r];

					for (0..vec_count) |vec_idx| {
						const xdots = x_cache[vec_idx];
						const sx_vec = xdots.sx;

						// Calculamos los términos base sumando la parte de 'y' (constante en este bucle)
						const d00 = xdots.dot_x_00 + dy00;
						const d10 = xdots.dot_x_10 + dy10;
						const d01 = xdots.dot_x_01 + dy01;
						const d11 = xdots.dot_x_11 + dy11;

						// Interpolación en X
						const interp0 = vector_math.mul_q15_round(sx_vec, d10 - d00) + d00;
						const interp1 = vector_math.mul_q15_round(sx_vec, d11 - d01) + d01;
														
						// Interpolación en Y
						const val = vector_math.mul_q15_round(sy_r, interp1 - interp0) + interp0;

						// Escritura lineal en memoria (Mucho más amigable para el caché/store buffer)
						out_ptr[vec_idx] = val * VEC_Q15_FOUR;
					}
				}
      }
    }
  }
}