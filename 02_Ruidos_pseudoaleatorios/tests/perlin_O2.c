// Cacheado de coordenadas de gradiente, valores suavizados y valores de ruido para evitar cálculos repetidos en la generación de chunks
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


	for (uint64_t j = 0; j < n_grads_side; j++) {
		for (uint64_t i = 0; i < n_grads_side; i++) {
			uint64_t x_grad = start_grid_x + i;
			uint64_t y_grad = start_grid_y + j;
			gradients[j][i] = perlin_gradients[hash(cfg.seed, x_grad, y_grad)];
		}
	}


	for (uint64_t y = 0; y < cfg.chunk_size; y++) {
		// En matemáticas, el eje Y crece hacia arriba
		// en arrays, el eje Y crece hacia abajo
		uint64_t noise_y = cfg.chunk_size - y - 1;

		int64_t global_y = global_pixel_y + (int64_t)noise_y;
		uint64_t val_idx_y = global_y & scale_mask;
		local_pos.y = cfg.values[val_idx_y];

		int64_t grid_y = (global_y >= 0 
			? global_y / iscale 
			: (global_y - iscale + 1) / iscale) - start_grid_y;
		int64_t grid_y1 = grid_y + 1;

		uint64_t row_offset = y * cfg.chunk_size;
		for (uint64_t x = 0; x < cfg.chunk_size; x++) {
			int64_t global_x = global_pixel_x + (int64_t)x;
			uint64_t val_idx_x = global_x & scale_mask;
			local_pos.x = cfg.values[val_idx_x];

			int64_t grid_x = (global_x >= 0 
				? global_x / iscale 
				: (global_x - iscale + 1) / iscale) - start_grid_x;
			int64_t grid_x1 = grid_x + 1;

			Vector2 grad_bl = gradients[grid_y][grid_x];
			Vector2 grad_br = gradients[grid_y][grid_x1];
			Vector2 grad_tl = gradients[grid_y1][grid_x];
			Vector2 grad_tr = gradients[grid_y1][grid_x1];

			float dot_bl = vec2_dot(grad_bl, local_pos);
			float dot_br = vec2_dot(grad_br, (Vector2){local_pos.x - 1.0f, local_pos.y});
			float dot_tl = vec2_dot(grad_tl, (Vector2){local_pos.x, local_pos.y - 1.0f});
			float dot_tr = vec2_dot(grad_tr, (Vector2){local_pos.x - 1.0f, local_pos.y - 1.0f});

			Vector2 smooth = (Vector2){
					cfg.smoothed_values[val_idx_x],
					cfg.smoothed_values[val_idx_y]
			};
			float value = bilinear_interp(dot_bl, dot_br, dot_tl, dot_tr, smooth);

			chunk[row_offset + x] = value;
		}
	}
}