const table = @import("../../core/f32/table.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

pub const RequiredAlignment: u29 = mode_meta.CacheLineBytes;
pub const sample_kind: mode_meta.SampleKind = .f32;

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
      @compileError("O1 requires SCALE to be a power of two");
    }
  }

  _ = chunk_size;
  _ = values_buf;
  _ = smoothed_buf;
}

pub fn perlin_generate_chunk2d(
  seed: u64,
  comptime chunk_size: u64,
  comptime scale: u64,
  world_x: i64,
  world_y: i64,
  out_buffer: []f32,
) !void {
  const initialized_seed: u64 = hash.custom_hash_init_v1(seed);

  const cs_u: u64 = chunk_size;
  const cs_i: i64 = @as(i64, @intCast(chunk_size));

  const sc_i: i64 = @as(i64, @intCast(scale));
  const sc_l: u6  = @as(u6, @intCast(@ctz(scale)));
  const sc_inv_f: f32 = 1.0 / @as(f32, @floatFromInt(sc_i));

  for (0..cs_u) |y| {
    const arr_local_y_i: i64 = cs_i - @as(i64, @intCast(y)) - 1;
    const arr_world_y_i: i64 = world_y + arr_local_y_i;

    const y_rel: f32 = math.fast_fract(@as(f32, @floatFromInt(arr_world_y_i)) * sc_inv_f);

    const grid_y0: i64 = arr_world_y_i >> sc_l;
    const grid_y1: i64 = grid_y0 + 1;

    const row_off_u: u64 = y * cs_u;
    for (0..cs_u) |x| {
      const arr_world_x_i: i64 = world_x + @as(i64, @intCast(x));

      const x_rel: f32 = math.fast_fract(@as(f32, @floatFromInt(arr_world_x_i)) * sc_inv_f);

      const grid_x0: i64 = arr_world_x_i >> sc_l;
      const grid_x1: i64 = grid_x0 + 1;

      const g_00: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y0)) & table.grad_mask];
      const g_10: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y0)) & table.grad_mask];
      const g_01: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y1)) & table.grad_mask];
      const g_11: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y1)) & table.grad_mask];

      const d_00: f32 = math.dot_prod_2d(g_00[0], g_00[1], x_rel, y_rel);
      const d_10: f32 = math.dot_prod_2d(g_10[0], g_10[1], x_rel - 1.0, y_rel);
      const d_01: f32 = math.dot_prod_2d(g_01[0], g_01[1], x_rel, y_rel - 1.0);
      const d_11: f32 = math.dot_prod_2d(g_11[0], g_11[1], x_rel - 1.0, y_rel - 1.0);

      const s_x: f32 = math.smooth_step(x_rel);
      const s_y: f32 = math.smooth_step(y_rel);

      const i_x0: f32 = math.lerp(d_00, d_10, s_x);
      const i_x1: f32 = math.lerp(d_01, d_11, s_x);
      const v_xy: f32 = math.lerp(i_x0, i_x1, s_y);

      out_buffer[row_off_u + x] = v_xy;
    }
  }
}