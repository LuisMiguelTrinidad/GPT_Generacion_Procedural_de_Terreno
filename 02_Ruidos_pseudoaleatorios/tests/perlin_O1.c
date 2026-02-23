// Implementación de aleatoreidad
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
		.lacunarity = lacunarity
	};
	return cfg;
}
void perlin_generate_chunk2d(PerlinConfig cfg, int64_t chunk_x, int64_t chunk_y, float *out_buffer) {
	float *chunk = out_buffer;

	// Es mas eficiente multiplicar que dividir así que calculamos el
	// inverso de la escala para multiplicar en lugar de dividir luego
	float inv_scale = 1.0f / cfg.scale;

	Vector2 local_pos = {0.0f, 0.0f};
	int64_t iscale = (int64_t)cfg.scale;

	int64_t global_pixel_x = chunk_x * (int64_t)cfg.chunk_size;
	int64_t global_pixel_y = chunk_y * (int64_t)cfg.chunk_size;

	for (uint64_t y = 0; y < cfg.chunk_size; y++) {
		// En matemáticas, el eje Y crece hacia arriba
		// en arrays, el eje Y crece hacia abajo
		uint64_t noise_y = cfg.chunk_size - y - 1;

		int64_t global_y = global_pixel_y + (int64_t)noise_y;
		local_pos.y = fast_fract((float)global_y * inv_scale);

		int64_t grid_y = global_y >= 0
			? global_y / iscale
			: (global_y - iscale + 1) / iscale;
		int64_t grid_y1 = grid_y + 1;

		uint64_t row_offset = y * cfg.chunk_size;
		for (uint64_t x = 0; x < cfg.chunk_size; x++) {
			int64_t global_x = global_pixel_x + (int64_t)x;
			local_pos.x = fast_fract((float)global_x * inv_scale);

			int64_t grid_x = global_x >= 0
				? global_x / iscale
				: (global_x - iscale + 1) / iscale;
			int64_t grid_x1 = grid_x + 1;

			Vector2 grad_bl = perlin_gradients[hash(cfg.seed, grid_x, grid_y)];
			Vector2 grad_br = perlin_gradients[hash(cfg.seed, grid_x1, grid_y)];
			Vector2 grad_tl = perlin_gradients[hash(cfg.seed, grid_x, grid_y1)];
			Vector2 grad_tr = perlin_gradients[hash(cfg.seed, grid_x1, grid_y1)];

			float dot_bl = vec2_dot(grad_bl, local_pos);
			float dot_br = vec2_dot(grad_br, (Vector2){local_pos.x - 1.0f, local_pos.y});
			float dot_tl = vec2_dot(grad_tl, (Vector2){local_pos.x, local_pos.y - 1.0f});
			float dot_tr = vec2_dot(grad_tr, (Vector2){local_pos.x - 1.0f, local_pos.y - 1.0f});

			Vector2 smooth = smoothstep_vec2(local_pos);
			float value = bilinear_interp(dot_bl, dot_br, dot_tl, dot_tr, smooth);

			chunk[row_offset + x] = value;
		}
	}
}