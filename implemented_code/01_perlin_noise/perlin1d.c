#include "perlin.h"
#include <stdlib.h>


static const float perlin1Dgradients[64] = {
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
inline static dotprod1D(float x, float y) {
    return x * y;
}

inline static lerp1D(float x_0, float x_n, float x_i) {
    return x_0 * (1 - x_i) + x_n * x_i;
}

inline static float getRandomGradient1D(long seed, long x) {
    srand(seed + x * 83492791);
    return perlin1Dgradients[rand() & 0x3F]; // & 0x3F para obtener un índice entre 0 y 63
}

// Implementación de la función pública
float* PerlinNoise1D(PerlinGenerator* cfg, long chunkIdx) {
    float *chunk = malloc(cfg->chunkSize * sizeof(float));

    for (long i = 0; i < cfg->chunkSize; i++) {
        float x_i = (float)i / cfg->chunkSize;
    }
}