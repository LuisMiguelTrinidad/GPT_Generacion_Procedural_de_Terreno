const table = @import("../../core/f32/table.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

pub const RequiredAlignment: u29 = mode_meta.CacheLineBytes;
pub const GradientCacheAlignment: u29 = mode_meta.CacheLineBytes;
pub const sample_kind: mode_meta.SampleKind = .f32;

pub fn gradient_cache_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
  const grids_per_side: u64 = @max(chunk_size / scale, @as(u64, 1));
  const gps: u64 = grids_per_side + 1;
  return @as(usize, @intCast(gps * gps)) * @sizeOf([2]f32);
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
      @compileError("O2 requires SCALE to be a power of two");
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
  noalias cached_values: []const f32,
  noalias cached_smoothed_values: []const f32,
  world_x: i64,
  world_y: i64,
  noalias out_buffer: []f32,
  noalias gradient_cache_buf: []u8,
) !void {
  const initialized_seed: u64 = hash.custom_hash_init_v1(seed);

  const cs_u: u64 = chunk_size;
  const cs_i: i64 = @as(i64, @intCast(chunk_size));

  const sc_u: u64 = scale;
  const sc_m: i64 = @as(i64, @intCast(sc_u - 1));
  const sc_l: u6  = @as(u6, @intCast(@ctz(sc_u))); 
	
  const grid_base_x: i64 = world_x >> sc_l;
  const grid_base_y: i64 = world_y >> sc_l;

  const grids_per_side: u64 = @max(cs_u >> sc_l, @as(u64, 1));
  const gps: usize = @as(usize, @intCast(grids_per_side + 1));
  const gradient_cache_ptr: [*][2]f32 = @ptrCast(@alignCast(gradient_cache_buf.ptr));
  const gradient_cache: [][2]f32 = gradient_cache_ptr[0..(gps * gps)];

  for (0..gps) |gy| {
    for (0..gps) |gx| {
      const u64_idx: u64 = hash.custom_hash_v1_no_init(
        initialized_seed,
        @as(u64, @bitCast(grid_base_x)) + gx,
        @as(u64, @bitCast(grid_base_y)) + gy,
      );
      gradient_cache[gy * gps + gx] = table.grad[u64_idx & table.grad_mask];
    }
  }

  for (0..cs_u) |y| {
    const arr_local_y_i: i64 = cs_i - @as(i64, @intCast(y)) - 1;
    const arr_world_y_i: i64 = world_y + arr_local_y_i;        

		const y_idx_local: u64 = @as(u64, @intCast(arr_world_y_i & sc_m));
    const y_rel: f32 = cached_values[y_idx_local];

    const grid_local_y: u64 = @as(u64, @intCast((arr_world_y_i >> sc_l) - grid_base_y));

    const row_off_u: u64 = @as(u64, @intCast(y * cs_u));
    for (0..cs_u) |x| {
      const arr_world_x_i: i64 = world_x + @as(i64, @intCast(x));
      
      const x_idx: u64 = @as(u64, @intCast(arr_world_x_i & sc_m));
      const x_rel: f32 = cached_values[x_idx];

      const grid_local_x: u64 = @as(u64, @intCast((arr_world_x_i >> sc_l) - grid_base_x));

      const g_00: [2]f32 = gradient_cache[grid_local_y * gps + grid_local_x];
      const g_10: [2]f32 = gradient_cache[grid_local_y * gps + (grid_local_x + 1)];
      const g_01: [2]f32 = gradient_cache[(grid_local_y + 1) * gps + grid_local_x];
      const g_11: [2]f32 = gradient_cache[(grid_local_y + 1) * gps + (grid_local_x + 1)];

      const d_00: f32 = math.dot_prod_2d(g_00[0], g_00[1], x_rel, y_rel);
      const d_10: f32 = math.dot_prod_2d(g_10[0], g_10[1], x_rel - 1.0, y_rel);
      const d_01: f32 = math.dot_prod_2d(g_01[0], g_01[1], x_rel, y_rel - 1.0);
      const d_11: f32 = math.dot_prod_2d(g_11[0], g_11[1], x_rel - 1.0, y_rel - 1.0);

      const s_x: f32 = cached_smoothed_values[x_idx];
      const s_y: f32 = cached_smoothed_values[y_idx_local];

      const i_x0: f32 = math.lerp(d_00, d_10, s_x);
      const i_x1: f32 = math.lerp(d_01, d_11, s_x);
      const v_xy: f32 = math.lerp(i_x0, i_x1, s_y);

      out_buffer[row_off_u + x] = v_xy;
    }
  }
}