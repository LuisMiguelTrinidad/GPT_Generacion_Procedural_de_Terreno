#ifndef PERLIN_H
#define PERLIN_H

typedef struct {
    long long       seed;
    unsigned long   chunkSize;
    float           scale;
    unsigned long   octaves;
    float           persistence;
    float           lacunarity;
} PerlinCfg;

float* PerlinNoiseChunk1D(PerlinCfg* cfg, long chunkIdx);
float* PerlinNoiseChunk2D(PerlinCfg* cfg, long chunkIdx, long chunkIdy);


#endif