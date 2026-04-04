const table = @import("../../core/f32/table.zig");
const types = @import("../../core/f32/types.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

pub const RequiredAlignment = @alignOf(f32);
pub const GCAlignment: comptime_int = @alignOf([2]f32);
pub const sample_kind: mode_meta.SampleKind = .f32;

pub fn gc_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
  const grids_per_side: u64 = @max(chunk_size / scale, @as(u64, 1));
  const gps: u64 = grids_per_side + 1;
  return @as(usize, @intCast(gps * gps)) * @sizeOf([2]f32);
}

pub fn perlin_init_config(
  values_buf: []f32,
  smoothed_buf: []f32,
  seed: u64,
  comptime chunk_size: u64,
  comptime scale: u64,
  comptime octaves: u64,
  comptime persistence: f32,
  comptime lacunarity: f32
) types.PerlinConfig {
  
  comptime {
    if ((@popCount(scale) != 1)) {
      @compileError("O2 requires SCALE to be a power of two");
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

pub fn perlin_generate_chunk2d(
  cfg: types.PerlinConfig, 
  chunk_x: i64, 
  chunk_y: i64, 
  out_buffer: []f32,
  gc_buf: []u8,
) !void {
	// cs = chunk size
  const cs_u: u64 = @intCast(cfg.chunk_size);
  const cs_i: i64 = @as(i64, @intCast(cfg.chunk_size));
	// sc = scale
  const sc_u: u64 = @intCast(cfg.scale);
  const sc_m: i64 = @as(i64, @intCast(sc_u - 1));
  const sc_l: u6  = @as(u6, @intCast(@ctz(sc_u))); 
	
	// Array-space world coordinate for the chunk origin
  const arr_world_base_x_i: i64 = chunk_x * cs_i;
  const arr_world_base_y_i: i64 = chunk_y * cs_i;

  // Noise-grid base coordinate for this chunk
  const noise_grid_base_x_i: i64 = arr_world_base_x_i >> sc_l;
  const noise_grid_base_y_i: i64 = arr_world_base_y_i >> sc_l;

  // gps = grids per chunk side (minimum 2 to cover cell corners)
  const gps: usize = @max(@as(u64, @intCast(cs_u >> sc_l)), 1) + 1;
  const gc_ptr: [*][2]f32 = @ptrCast(@alignCast(gc_buf.ptr));
  const gc: [][2]f32 = gc_ptr[0..(gps * gps)];

  for (0..gps) |gy| {
    for (0..gps) |gx| {
      const u64_idx: u64 = hash.custom_hash_v1_no_init(
        cfg.seed,
        @as(u64, @bitCast(noise_grid_base_x_i)) + gx,
        @as(u64, @bitCast(noise_grid_base_y_i)) + gy,
      );
      gc[gy * gps + gx] = table.grad[u64_idx & table.grad_mask];
    }
  }

  for (0..cs_u) |y| {
    // Noise-space Y grows upward while array rows grow downward
    const arr_local_y_i: i64 = cs_i - @as(i64, @intCast(y)) - 1;
    const arr_world_y_i: i64 = arr_world_base_y_i + arr_local_y_i;        
    
    // Noise-local coordinate inside current scale cell
		const noise_local_y_idx_u: u64 = @as(u64, @intCast(arr_world_y_i & sc_m));
		const noise_local_y_f: f32 = cfg.cached_values[noise_local_y_idx_u];

		// Local grid index inside cached gradients
    const noise_grid_local_y_u: u64 = @as(u64, @intCast((arr_world_y_i >> sc_l) - noise_grid_base_y_i));
		
    // ro=row offset (hoisting)
    const row_off_u: u64 = @as(u64, @intCast(y * cs_u));
    for (0..cs_u) |x| {
      const arr_world_x_i: i64 = arr_world_base_x_i + @as(i64, @intCast(x));
      
      const noise_local_x_idx_u: u64 = @as(u64, @intCast(arr_world_x_i & sc_m));
      const noise_local_x_f: f32 = cfg.cached_values[noise_local_x_idx_u];

      const noise_grid_local_x_u: u64 = @as(u64, @intCast((arr_world_x_i >> sc_l) - noise_grid_base_x_i));

      const g00: [2]f32 = gc[noise_grid_local_y_u * gps + noise_grid_local_x_u];
      const g10: [2]f32 = gc[noise_grid_local_y_u * gps + (noise_grid_local_x_u + 1)];
      const g01: [2]f32 = gc[(noise_grid_local_y_u + 1) * gps + noise_grid_local_x_u];
      const g11: [2]f32 = gc[(noise_grid_local_y_u + 1) * gps + (noise_grid_local_x_u + 1)];

      const d00: f32 = math.dot_prod_2d(g00[0], g00[1], noise_local_x_f, noise_local_y_f);
      const d10: f32 = math.dot_prod_2d(g10[0], g10[1], noise_local_x_f - 1.0, noise_local_y_f);
      const d01: f32 = math.dot_prod_2d(g01[0], g01[1], noise_local_x_f, noise_local_y_f - 1.0);
      const d11: f32 = math.dot_prod_2d(g11[0], g11[1], noise_local_x_f - 1.0, noise_local_y_f - 1.0);

      const sx = cfg.cached_smoothed_values[noise_local_x_idx_u];
      const sy = cfg.cached_smoothed_values[noise_local_y_idx_u];

      const v = math.lerp(
        math.lerp(d00, d10, sx),
        math.lerp(d01, d11, sx),
        sy
      );

      out_buffer[row_off_u + x] = v;
    }
  }
}