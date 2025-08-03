#include "perlin.h"

#include <stdlib.h>
#include <math.h>

typedef struct {
	float x;
	float y;
} fV2D;

static const fV2D perlin2Dgradients[64] = {
    { 0.00000000, -1.41421356}, { 0.13861717, -1.40740374}, { 0.27589938, -1.38703985}, { 0.41052453, -1.35331800},
	{ 0.54119610, -1.30656296}, { 0.66665566, -1.24722501}, { 0.78569496, -1.17587560}, { 0.89716759, -1.09320187},
	{ 1.00000000, -1.00000000}, { 1.09320187, -0.89716759}, { 1.17587560, -0.78569496}, { 1.24722501, -0.66665566},
	{ 1.30656296, -0.54119610}, { 1.35331800, -0.41052453}, { 1.38703985, -0.27589938}, { 1.40740374, -0.13861717},
	{ 1.41421356,  0.00000000}, { 1.40740374,  0.13861717}, { 1.38703985,  0.27589938}, { 1.35331800,  0.41052453},
	{ 1.30656296,  0.54119610}, { 1.24722501,  0.66665566}, { 1.17587560,  0.78569496}, { 1.09320187,  0.89716759},
	{ 1.00000000,  1.00000000}, { 0.89716759,  1.09320187}, { 0.78569496,  1.17587560}, { 0.66665566,  1.24722501},
	{ 0.54119610,  1.30656296}, { 0.41052453,  1.35331800}, { 0.27589938,  1.38703985}, { 0.13861717,  1.40740374},
	{ 0.00000000,  1.41421356}, {-0.13861717,  1.40740374}, {-0.27589938,  1.38703985}, {-0.41052453,  1.35331800},
	{-0.54119610,  1.30656296}, {-0.66665566,  1.24722501}, {-0.78569496,  1.17587560}, {-0.89716759,  1.09320187},
	{-1.00000000,  1.00000000}, {-1.09320187,  0.89716759}, {-1.17587560,  0.78569496}, {-1.24722501,  0.66665566},
	{-1.30656296,  0.54119610}, {-1.35331800,  0.41052453}, {-1.38703985,  0.27589938}, {-1.40740374,  0.13861717},
	{-1.41421356,  0.00000000}, {-1.40740374, -0.13861717}, {-1.38703985, -0.27589938}, {-1.35331800, -0.41052453},
	{-1.30656296, -0.54119610}, {-1.24722501, -0.66665566}, {-1.17587560, -0.78569496}, {-1.09320187, -0.89716759},
	{-1.00000000, -1.00000000}, {-0.89716759, -1.09320187}, {-0.78569496, -1.17587560}, {-0.66665566, -1.24722501},
	{-0.54119610, -1.30656296}, {-0.41052453, -1.35331800}, {-0.27589938, -1.38703985}, {-0.13861717, -1.40740374},
};


inline static float dotP2D(fV2D a, fV2D b) {
    return (a.x * b.x + a.y * b.y);
}

inline static float lerp2D(float b_l, float b_r, float t_l, float t_r, fV2D point) {
    float bottom = (1 - point.x) * b_l + point.x * b_r; 
    float top = (1 - point.x) * t_l + point.x * t_r;
    return (1 - point.y) * bottom + point.y * top;
}

inline static fV2D getRandomRandomGradient2D(long seed, long x, long y) {
	srand(seed + x * 83492791 + y * 19349663);
	return (fV2D){
		(float)rand() / RAND_MAX,
		(float)rand() / RAND_MAX
	};
}

inline static fV2D getRandomGradient2D(long seed, long x, long y) {
    srand(seed + x * 83492791 + y * 19349663);
    return perlin2Dgradients[rand() & 0x3F]; // & 0x3F para obtener un índice entre 0 y 63
}

inline static fV2D getGradient2D(long seed, long x, long y) {
	seed ^= x * 83492791;
	seed ^= y * 39916801;
	seed ^= (seed * 19349663) >> 16;
	seed ^= seed >> 32;

	return perlin2Dgradients[seed&0x3F];
}

inline fV2D fadequintic2D(fV2D t) {
	return (fV2D){
		t.x * t.x * t.x * (t.x * (t.x * 6 - 15) + 10),
		t.y * t.y * t.y * (t.y * (t.y * 6 - 15) + 10)
	};
}

inline fV2D fadecubic(fV2D t) {
	return (fV2D){
		t.x * t.x * (3 - 2 * t.x),
		t.y * t.y * (3 - 2 * t.y)
	};
}

float* PerlinNoiseChunk2D(PerlinCfg* cfg, long chunkX, long chunkY) {
    float *chunk = calloc(cfg->chunkSize * cfg->chunkSize, sizeof(float));

    float total_persistence = 0.0f;
    for (long octave = 0; octave < cfg->octaves; octave++) {
        total_persistence += powf(cfg->persistence, -octave);
    }

    for (long octave = 0; octave < cfg->octaves; octave++) {
        float actual_scale = cfg->scale / powf(cfg->lacunarity, octave);
        float actual_persistence = powf(cfg->persistence, -octave) / total_persistence;

        for (long i = 0; i < cfg->chunkSize; i++) {
			int rev_i = cfg->chunkSize - i - 1;
			for (long j = 0; j < cfg->chunkSize; j++) {
				fV2D x_i_i = {
					fmodf((float)i / actual_scale, 1.f),
					fmodf((float)j / actual_scale, 1.f)
				};
				/* Benchmarkear esto
				fV2D x_i_i = {
					((float)i * inv_scale) - floorf((float)i * inv_scale),
					((float)j * inv_scale) - floorf((float)j * inv_scale)
				};
				*/
				long x_0_0 = (chunkY * cfg->chunkSize + i) / (actual_scale);
				long x_1_1 = x_0_0 + 1;
				long y_0_0 = (chunkX * cfg->chunkSize + j) / (actual_scale);
				long y_1_1 = y_0_0 + 1;

                fV2D g_0_0 = getGradient2D(cfg->seed, x_0_0, y_0_0); // Inf lft
                fV2D g_1_0 = getGradient2D(cfg->seed, x_1_1, y_0_0); // Inf rgt
                fV2D g_0_1 = getGradient2D(cfg->seed, x_0_0, y_1_1); // Sup lft
                fV2D g_1_1 = getGradient2D(cfg->seed, x_1_1, y_1_1); // Sup rgt

				float v_0_0 = dotP2D(g_0_0, x_i_i);									// Esquina inferior izquierda
                float v_1_0 = dotP2D(g_1_0, (fV2D){x_i_i.x - 1.0f, x_i_i.y});		// Esquina inferior derecha
                float v_0_1 = dotP2D(g_0_1, (fV2D){x_i_i.x, x_i_i.y - 1.0f});		// Esquina superior izquierda				
				float v_1_1 = dotP2D(g_1_1, (fV2D){x_i_i.x - 1.0f, x_i_i.y - 1.0f});// Esquina superior derecha

				fV2D x_s_s = fadequintic2D(x_i_i);
                float v_i_i = lerp2D(v_0_0, v_1_0, v_0_1, v_1_1, x_s_s);

				chunk[rev_i * cfg->chunkSize + j] += v_i_i * actual_persistence;
			}
        }
    }
    return chunk;
}