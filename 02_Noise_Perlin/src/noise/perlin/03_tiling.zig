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
      @compileError("O3 requires SCALE to be a power of two");
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
) !void {
  const initialized_seed: u64 = hash.custom_hash_init_v1(seed);

  const cs_u: u64 = chunk_size;
  const sc_u: u64 = scale;
  const sc_m: u64 = sc_u - 1;
  const sc_l: u6  = @as(u6, @intCast(@ctz(sc_u)));

  const grid_base_x: i64 = world_x >> sc_l;
  const grid_base_y: i64 = world_y >> sc_l;

	const n_cells: u64 = @max(cs_u >> sc_l, @as(u64, 1));

  const arr_world_off_x_u: u64 = @as(u64, @bitCast(world_x))&sc_m;
  const arr_world_off_y_u: u64 = @as(u64, @bitCast(world_y))&sc_m;

  const min_dim: u64 = @min(cs_u, sc_u);

  for (0..n_cells) |gy| {
		const noise_local_tile_y_u: u64 = n_cells - gy - 1;
		const arr_world_tile_y_u: u64 = noise_local_tile_y_u * sc_u;

		for (0..n_cells) |gx| {
			const arr_world_tile_x_u: u64 = gx * sc_u;

      const grid_x0: i64 = grid_base_x + @as(i64, @intCast(gx));
      const grid_y0: i64 = grid_base_y + @as(i64, @intCast(gy));
      const grid_x1: i64 = grid_x0 + 1;
      const grid_y1: i64 = grid_y0 + 1;

      const g_00: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y0)) & table.grad_mask];
      const g_10: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y0)) & table.grad_mask];
      const g_01: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x0), @bitCast(grid_y1)) & table.grad_mask];
      const g_11: [2]f32 = table.grad[hash.custom_hash_v1_no_init(initialized_seed, @bitCast(grid_x1), @bitCast(grid_y1)) & table.grad_mask];

			for (0..min_dim) |ly| {
        const noise_local_y_u: u64 = min_dim - ly - 1;
        const y_idx_local: u64 = (noise_local_y_u -% arr_world_off_y_u) & sc_m;
        const y_rel: f32 = cached_values[y_idx_local];

        const matrix_offset: u64 = arr_world_tile_x_u + (arr_world_tile_y_u + ly) * cs_u;

				for (0..min_dim) |lx| {
          const x_idx: u64 = (lx + arr_world_off_x_u) & sc_m;
          const x_rel: f32 = cached_values[x_idx];

          const d_00: f32 = math.dot_prod_2d(g_00[0], g_00[1], x_rel, y_rel);
          const d_10: f32 = math.dot_prod_2d(g_10[0], g_10[1], x_rel - 1.0, y_rel);
          const d_01: f32 = math.dot_prod_2d(g_01[0], g_01[1], x_rel, y_rel - 1.0);
          const d_11: f32 = math.dot_prod_2d(g_11[0], g_11[1], x_rel - 1.0, y_rel - 1.0);

          const s_x: f32 = cached_smoothed_values[x_idx];
          const s_y: f32 = cached_smoothed_values[y_idx_local];

          const i_x0: f32 = math.lerp(d_00, d_10, s_x);
          const i_x1: f32 = math.lerp(d_01, d_11, s_x);
          const v_xy: f32 = math.lerp(i_x0, i_x1, s_y);

					out_buffer[matrix_offset + lx] = v_xy;
				}
			}
    }
  }
}
