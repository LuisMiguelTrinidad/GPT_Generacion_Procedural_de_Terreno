#include "perlin.h"

#include <stdlib.h>
#include <math.h>
#include <stdint.h>

float dotP2D(fV2D a, fV2D b) {
    return (a.x * b.x + a.y * b.y);
}

float lerp2D(float b_l, float b_r, float t_l, float t_r, fV2D point) {
    float bottom = (1 - point.x) * b_l + point.x * b_r; 
    float top = (1 - point.x) * t_l + point.x * t_r;
    return (1 - point.y) * bottom + point.y * top;
}

fV2D getGradient2D(uint64_t seed, int64_t x, int64_t y) {
    const uint64_t C1 = 0xbf58476d1ce4e5b9; // Wyhash64
    const uint64_t C2 = 0xff51afd7ed558ccd; // MurMurHash3 finalizer
    const uint64_t C3 = 0xc4ceb9fe1a85ec53; // MurMurHash3 finalizer
    const uint64_t C4 = 0x9e3779b97f4a7c15; // MurMurHash3

    // Abusamos fma para multiplicar y sumar en una sola instruccion
    seed ^= (x * C1 + C3) ^ (y * C2 + C4);
    // Usamos el intrínsico de rotación de bits para evitar pérdidas de entropía
    seed *= seed + C3;
    seed *= ROTATE_RIGHT(seed, 32) + C4;
    seed ^= ROTATE_RIGHT(seed, 32);

    return perlin2Dgradients[(seed & 0xFF)];
}

float smoothstep(float t) {
	return t * t * t * (t * (t * 6 - 15) + 10);
}

PerlinCfg initPerlinCfg(uint64_t seed, uint64_t chunkSize, uint64_t scale, uint64_t octaves, float persistence, float lacunarity) {
    PerlinCfg cfg = {
        .seed           = seed,
        .chunkSize      = chunkSize,
        .scale          = scale,
        .octaves        = octaves,
        .persistence    = persistence,
        .lacunarity     = lacunarity,
        .smoothedValues = (float*)malloc(chunkSize * sizeof(float))
    };
    
    for (uint64_t i = 0; i < PERLIN_TABLE_SIZE; i++) {
        uint64_t j = (i + rand()) & (PERLIN_TABLE_SIZE - 1);
        fV2D t = perlin2Dgradients[j];
        perlin2Dgradients[j] = perlin2Dgradients[i];
        perlin2Dgradients[i] = t;
    }

    for (uint64_t i = 0; i < cfg.scale; i++) {
        cfg.smoothedValues[i] = smoothstep(((float)i / cfg.scale));
    }

    return cfg;
}

fV2D* precalculate_gradients(PerlinCfg cfg, int64_t chunkX, int64_t chunkY, uint64_t n_grads_side) {
    fV2D* gradients = (fV2D*)malloc(n_grads_side * n_grads_side * sizeof(fV2D));
    int64_t cells_per_chunk = (int64_t)n_grads_side - 1;

    for (uint64_t j = 0; j < n_grads_side; j++) {
        for (uint64_t i = 0; i < n_grads_side; i++) {
            int64_t x = chunkX * cells_per_chunk + (int64_t)i;
            int64_t y = chunkY * cells_per_chunk + (int64_t)j; // <- consistente con X
            gradients[j * n_grads_side + i] = getGradient2D(cfg.seed, x, y);
        }
    }
    return gradients;
}

float* PerlinNoiseChunk2D(PerlinCfg cfg, int64_t chunkX, int64_t chunkY) {
    float* chunk = malloc(cfg.chunkSize * cfg.chunkSize * sizeof(float));
	
	uint64_t scale_mask = cfg.scale - 1;
	float inv_scale = 1.f / cfg.scale; //Invertimos para evitar el coste de una división en el bucle

    // Precalculamos los gradientes para evitar llamadas repetidas a la función de hash
    uint64_t n_grads_side = (cfg.chunkSize / cfg.scale) + 1;
    fV2D* gradients = precalculate_gradients(cfg, chunkX, chunkY, n_grads_side);
    
	fV2D x_i_i = {0.f,0.f};
    for (uint64_t i = 0; i < cfg.chunkSize; i++) {
		x_i_i.y = (i * inv_scale) - floorf(i * inv_scale);

		uint64_t rev_i = cfg.chunkSize - i - 1;
		
        int64_t y_0_0 = i / (cfg.scale); //MAL, asume que chunkSize es multiplo de scale
        int64_t y_1_1 = y_0_0 + 1;
        
		for (uint64_t j = 0; j < cfg.chunkSize; j++) {
			x_i_i.x = (j * inv_scale) - floorf(j * inv_scale);

			int64_t x_0_0 = j / (cfg.scale); //MAL, asume que chunkSize es multiplo de scale
			int64_t x_1_1 = x_0_0 + 1;

            fV2D g_0_0 = gradients[y_0_0 * n_grads_side + x_0_0]; // Inf lft
            fV2D g_1_0 = gradients[y_0_0 * n_grads_side + x_1_1]; // Inf rgt
            fV2D g_0_1 = gradients[y_1_1 * n_grads_side + x_0_0]; // Sup lft
            fV2D g_1_1 = gradients[y_1_1 * n_grads_side + x_1_1]; // Sup rgt

			float v_0_0 = dotP2D(g_0_0, x_i_i);									// Esquina inferior izquierda
            float v_1_0 = dotP2D(g_1_0, (fV2D){x_i_i.x - 1.0f, x_i_i.y});		// Esquina inferior derecha
        	float v_0_1 = dotP2D(g_0_1, (fV2D){x_i_i.x, x_i_i.y - 1.0f});		// Esquina superior izquierda				
			float v_1_1 = dotP2D(g_1_1, (fV2D){x_i_i.x - 1.0f, x_i_i.y - 1.0f});// Esquina superior derecha

			fV2D x_s_s = (fV2D){cfg.smoothedValues[j&scale_mask],cfg.smoothedValues[i&scale_mask]}; // Scale es una potencia de 2, por eso se puede hacer esto
            float v_i_i = lerp2D(v_0_0, v_1_0, v_0_1, v_1_1, x_s_s);

			chunk[rev_i * cfg.chunkSize + j] = v_i_i;
		}
    }
    free(gradients);
    
    return chunk;
}