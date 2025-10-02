/*
#include "perlin.h"

#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#define PERLIN_1D_TABLE_SIZE 64

static const float perlin1Dgradients[PERLIN_1D_TABLE_SIZE] = {
    -1.00000, -0.96875, -0.93750 ,-0.90625, -0.87500, -0.84375, -0.81250, -0.78125,
    -0.75000, -0.71875, -0.68750, -0.65625, -0.62500, -0.59375, -0.56250, -0.53125,
    -0.50000, -0.46875, -0.43750, -0.40625, -0.37500, -0.34375, -0.31250, -0.28125,
    -0.25000, -0.21875, -0.18750, -0.15625, -0.12500, -0.09375, -0.06250, -0.03125,
     0.03125,  0.06250,  0.09375,  0.12500,  0.15625,  0.18750,  0.21875,  0.25000, 
     0.28125,  0.31250,  0.34375,  0.37500,  0.40625,  0.43750,  0.46875,  0.50000, 
     0.53125,  0.56250,  0.59375,  0.62500,  0.65625,  0.68750,  0.71875,  0.75000, 
     0.78125,  0.81250,  0.84375,  0.87500,  0.90625,  0.93750,  0.96875,  1.00000
};

// Especificamos inline para que el compilador pueda optimizar estas funciones
// Especificamos static para que estas funciones sean privadas a este archivo
float dotP1D(float x, float y) {
    return x * y;
}

float lerp1D(float x_0, float x_n, float x_i) {
    return x_0 * (1 - x_i) + x_n * x_i;
}

float getRandomGradient1D(long seed, long x) {
    srand(seed + x * 83492791);
    return perlin1Dgradients[rand() & 0x3F]; // & 0x3F para obtener un índice entre 0 y 63
}

float getGradient1D(long seed, long x) {
	seed ^= (x * 237147250358685349 << 32) ^ ((seed * 992405828216649089) >> 16);
	seed ^= seed >> 32;

	return perlin1Dgradients[seed&(PERLIN_1D_TABLE_SIZE - 1)];
}

float fadequintic1D(float t) {
    return t * t * t * (t*(t*6-15) + 10);
}

float fadecubic1D(float t) {
    return t * t * (3 - 2*t);
}

float* PerlinNoiseChunk1D(PerlinCfg* cfg, long chunkX) {
    float *chunk = calloc(cfg->chunkSize, sizeof(float));

    float total_persistence = 0.0f;
    for (long octave = 0; octave < cfg->octaves; octave++) {
        total_persistence += powf(cfg->persistence, -octave);
    }

    for (long octave = 0; octave < cfg->octaves; octave++) {
        float actual_scale = cfg->scale / pow(cfg->lacunarity, octave);
        float actual_persistence = powf(cfg->persistence, -octave) / total_persistence;

        for (long i = 0; i < cfg->chunkSize; i++) {
            float x_i = fmodf((float)i / actual_scale, 1.0f);

            long x_0 = (chunkX * cfg->chunkSize + i) / (actual_scale);
            long x_1 = x_0 + 1;

            float g_0 = getGradient1D(cfg->seed, x_0);
            float g_1 = getGradient1D(cfg->seed, x_1);

            float v_0 = dotP1D(g_0, x_i);
			float v_1 = dotP1D(g_1, x_i-1.0f);
            
            float x_s = fadequintic1D(x_i);
			float v_i = lerp1D(v_0, v_1, x_s);

			chunk[i] += v_i * actual_persistence;
        }
    }
    return chunk;
}
*/