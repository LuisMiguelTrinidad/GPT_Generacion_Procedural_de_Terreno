const table = @import("../../core/f32/table.zig");
const types = @import("../../core/f32/types.zig");

const hash = @import("../../core/shared/hash.zig");
const math = @import("../../core/shared/math.zig");

const mode_meta = @import("mode_meta.zig");

pub const RequiredAlignment: u29 = @alignOf(f32);
pub const sample_kind: mode_meta.SampleKind = .f32;

pub fn workspace_bytes(comptime chunk_size: u64, comptime scale: u64) usize {
	const min_dim: u64 = @min(chunk_size, scale);
	return @as(usize, @intCast(min_dim)) * @sizeOf(f32) * 3;
}

comptime {
	if (@popCount(@as(u64, RequiredAlignment)) != 1) {
		@compileError("RequiredAlignment must be a non-zero power of two");
	}
}

inline fn fill_x_cache(
	x_sx: [*]f32,
	x_base_0: [*]f32,
	x_base_diff: [*]f32,
	elem_count: usize,
	values_cache: [*]const f32,
	smooth_cache: [*]const f32,
	g00x: f32,
	g10x: f32,
	g01x: f32,
	g11x: f32,
) void {
	for (0..elem_count) |idx| {
		const x: f32 = values_cache[idx];
		const sx: f32 = smooth_cache[idx];
		const xm1: f32 = x - 1.0;

		const dx00: f32 = g00x * x;
		const dx10: f32 = g10x * xm1;
		const dx01: f32 = g01x * x;
		const dx11: f32 = g11x * xm1;

		const base_0: f32 = @mulAdd(f32, sx, dx10 - dx00, dx00);
		const base_1: f32 = @mulAdd(f32, sx, dx11 - dx01, dx01);

		x_sx[idx] = sx;
		x_base_0[idx] = base_0;
		x_base_diff[idx] = base_1 - base_0;
	}
}

pub inline fn perlin_init_config(
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
	noalias out_buffer: []f32,
	noalias workspace_buf: []u8,
	comptime chunk_size: u64,
	comptime scale: u64,
) !void {
	const cs_u: u64 = chunk_size;
	const cs_l: u6 = @as(u6, @intCast(@ctz(cs_u)));

	const sc_u: u64 = scale;
	const sc_m: u64 = sc_u - 1;
	const sc_l: u6 = @as(u6, @intCast(@ctz(sc_u)));

	const arr_world_base_x_i: i64 = chunk_x << cs_l;
	const arr_world_base_y_i: i64 = chunk_y << cs_l;
	const noise_grid_base_x_i: i64 = arr_world_base_x_i >> sc_l;
	const noise_grid_base_y_i: i64 = arr_world_base_y_i >> sc_l;

	const grids_per_side: u64 = @max(cs_u >> sc_l, @as(u64, 1));
	const gps: usize = @as(usize, @intCast(grids_per_side + 1));

	const arr_world_off_x_u: u64 = @as(u64, @bitCast(arr_world_base_x_i)) & sc_m;
	const arr_world_off_y_u: u64 = @as(u64, @bitCast(arr_world_base_y_i)) & sc_m;

	const min_dim_u: u64 = @min(chunk_size, scale);
	const min_dim: usize = @as(usize, @intCast(min_dim_u));

	const values_cache: [*]const f32 = cfg.cached_values.ptr + @as(u64, @intCast(arr_world_off_x_u));
	const smooth_cache: [*]const f32 = cfg.cached_smoothed_values.ptr + @as(u64, @intCast(arr_world_off_x_u));

	const x_sx: [*]f32 = @ptrCast(@alignCast(workspace_buf.ptr));
	const x_base_0: [*]f32 = x_sx + min_dim;
	const x_base_diff: [*]f32 = x_base_0 + min_dim;

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

			const g00x: f32 = table.grad_table[0][g00_idx];
			const g10x: f32 = table.grad_table[0][g10_idx];
			const g01x: f32 = table.grad_table[0][g01_idx];
			const g11x: f32 = table.grad_table[0][g11_idx];

			const g00y_s: f32 = table.grad_table[1][g00_idx];
			const g10y_s: f32 = table.grad_table[1][g10_idx];
			const g01y_s: f32 = table.grad_table[1][g01_idx];
			const g11y_s: f32 = table.grad_table[1][g11_idx];
			const g10y_minus_g00y: f32 = g10y_s - g00y_s;
			const g11y_minus_g01y: f32 = g11y_s - g01y_s;

			fill_x_cache(
				x_sx,
				x_base_0,
				x_base_diff,
				min_dim,
				values_cache,
				smooth_cache,
				g00x,
				g10x,
				g01x,
				g11x,
			);

			var y_idx: u64 = (min_dim_u - 1 - arr_world_off_y_u) & sc_m;
			var out_row_ptr: [*]f32 = out_buffer.ptr + arr_world_tile_x_u + (arr_world_tile_y_u << cs_l);

			for (0..min_dim_u) |_| {
				const yf: f32 = cfg.cached_values[y_idx];
				const sy: f32 = cfg.cached_smoothed_values[y_idx];
				const ym1: f32 = yf - 1.0;

				const dy00: f32 = g00y_s * yf;
				const dy01: f32 = g01y_s * ym1;
				const diff0_s: f32 = g10y_minus_g00y * yf;
				const diff1_s: f32 = g11y_minus_g01y * ym1;

				const y_c1: f32 = @mulAdd(f32, sy, dy01 - dy00, dy00);
				const y_c2: f32 = @mulAdd(f32, sy, diff1_s - diff0_s, diff0_s);

				for (0..min_dim) |idx| {
					const term_bx: f32 = @mulAdd(f32, sy, x_base_diff[idx], x_base_0[idx]);
					out_row_ptr[idx] = @mulAdd(f32, x_sx[idx], y_c2, y_c1 + term_bx);
				}

				y_idx = (y_idx -% 1) & sc_m;
				out_row_ptr += cs_u;
			}
		}
	}
}
