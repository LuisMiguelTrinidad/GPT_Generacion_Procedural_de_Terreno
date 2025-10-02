#ifndef PERLIN_H
#define PERLIN_H

#include <stdint.h>
#include <math.h>

#if __STDC_VERSION__ >= 202311L
    #include <stdbit.h>
    #define ROTATE_RIGHT(x, n) __builtin_stdc_rotate_right(x, n)
#else
    #define ROTATE_RIGHT(x, n) (((x) >> (n)) | ((x) << (64 - (n))))
#endif

#define PERLIN_TABLE_SIZE 256
typedef struct {
    uint64_t    seed;
    uint64_t    chunkSize;
    uint64_t    scale;
    uint64_t    octaves;
    float       persistence;
    float       lacunarity;
    float       *smoothedValues;
} PerlinCfg;

typedef struct{
    float x;
    float y;
} fV2D;

extern fV2D perlin2Dgradients[PERLIN_TABLE_SIZE];

PerlinCfg initPerlinCfg(uint64_t seed, uint64_t chunkSize, uint64_t scale, uint64_t octaves, float persistence, float lacunarity);
float *PerlinNoiseChunk1D(PerlinCfg cfg, int64_t chunkIdx);
float *PerlinNoiseChunk2D(PerlinCfg cfg, int64_t chunkIdx, int64_t chunkIdy);

#endif