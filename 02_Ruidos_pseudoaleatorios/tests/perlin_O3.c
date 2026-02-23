// Tiling
#include "../perlin.h"

PerlinConfig perlin_init_config(
	uint64_t seed,
	uint64_t chunk_size,
	uint64_t scale,
	uint64_t octaves,
	float persistence,
	float lacunarity
) {
	PerlinConfig cfg = {
		.seed = seed,
		.chunk_size = chunk_size,
		.scale = scale,
		.octaves = octaves,
		.persistence = persistence,
		.lacunarity = lacunarity,
		.values = (float *)malloc(scale * sizeof(float)),
		.smoothed_values = (float *)malloc(scale * sizeof(float))};

	for (uint64_t i = 0; i < scale; i++) {
		cfg.values[i] = (float)i / scale;
		cfg.smoothed_values[i] = smoothstep_scalar(((float)i / scale));
	}
	return cfg;
}
void perlin_generate_chunk2d(PerlinConfig cfg, int64_t chunk_x, int64_t chunk_y, float *out_buffer) {
	float *chunk = out_buffer;
	
	Vector2 local_pos = {0.0f, 0.0f};
	int64_t iscale = (int64_t)cfg.scale;

	int64_t global_pixel_x = chunk_x * (int64_t)cfg.chunk_size;
	int64_t global_pixel_y = chunk_y * (int64_t)cfg.chunk_size;

	uint64_t scale_mask = cfg.scale - 1;

	uint64_t grids_per_chunk = cfg.chunk_size / cfg.scale > 0
		? (cfg.chunk_size / cfg.scale)
		: 1;
	uint64_t n_grads_side = grids_per_chunk + 1;
	Vector2 gradients[n_grads_side][n_grads_side];

	// Floor division (hacia -inf): C trunca hacia 0, 
	// necesitamos floor para negativos
	// Fórmula: a >= 0 ? a/b : (a - b + 1) / b
	int64_t start_grid_x = global_pixel_x >= 0
		? global_pixel_x / iscale
		: (global_pixel_x - iscale + 1) / iscale;
	int64_t start_grid_y = global_pixel_y >= 0
		? global_pixel_y / iscale
		: (global_pixel_y - iscale + 1) / iscale;

	// Offsets globales para correcta indexacion en tablas precalculadas (tiling)
	// El AND bit a bit funciona correctamente con complemento a 2 para valores negativos
	uint64_t global_offset_x = global_pixel_x & scale_mask;
	uint64_t global_offset_y = global_pixel_y & scale_mask;

	for (uint64_t j = 0; j < n_grads_side; j++) {
		for (uint64_t i = 0; i < n_grads_side; i++) {
			uint64_t x_grad = start_grid_x + i;
			uint64_t y_grad = start_grid_y + j;
			gradients[j][i] = perlin_gradients[hash(cfg.seed, x_grad, y_grad)];
		}
	}

	uint64_t min_dim = (cfg.chunk_size < cfg.scale)
		? cfg.chunk_size
		: cfg.scale;

	for (uint64_t y = 0; y < grids_per_chunk; y++) {
		// En matemáticas, el eje Y crece hacia arriba
		// en arrays, el eje Y crece hacia abajo
		uint64_t noise_y = grids_per_chunk - y - 1;
		uint64_t y_start = noise_y * cfg.scale;

		for (uint64_t x = 0; x < grids_per_chunk; x++) {
			uint64_t x_start = x * cfg.scale;

			Vector2 grad_bl = gradients[y][x];
			Vector2 grad_br = gradients[y][x + 1];
			Vector2 grad_tl = gradients[y + 1][x];
			Vector2 grad_tr = gradients[y + 1][x + 1];

			for (uint64_t ly = 0; ly < min_dim; ly++) {
				uint64_t local_noise_y = min_dim - ly - 1;
				uint64_t val_idx_y = (local_noise_y - global_offset_y) & scale_mask;

				local_pos.y = cfg.values[val_idx_y];

				uint64_t index_precalculated = x_start + (y_start + ly) * cfg.chunk_size;

				for (uint64_t lx = 0; lx < min_dim; lx++) {
					uint64_t val_idx_x = (lx + global_offset_x) & scale_mask;
					local_pos.x = cfg.values[val_idx_x];

					float dot_bl = vec2_dot(grad_bl, local_pos);
					float dot_br = vec2_dot(grad_br, (Vector2){local_pos.x - 1.0f, local_pos.y});
					float dot_tl = vec2_dot(grad_tl, (Vector2){local_pos.x, local_pos.y - 1.0f});
					float dot_tr = vec2_dot(grad_tr, (Vector2){local_pos.x - 1.0f, local_pos.y - 1.0f});

					Vector2 smooth = (Vector2){
						cfg.smoothed_values[val_idx_x],
						cfg.smoothed_values[val_idx_y]};
					chunk[index_precalculated + lx] = bilinear_interp(dot_bl, dot_br, dot_tl, dot_tr, smooth);
				}
			}
		}
	}
}