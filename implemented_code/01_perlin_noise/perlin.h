#ifndef PERLIN_H
#define PERLIN_H

typedef struct {
    long            seed;
    unsigned long   chunkSize;
    unsigned long   scale;
    unsigned long   octaves;
    float           persistence;
    float           lacunarity;
    float*          smoothedValues;
} PerlinCfg;

PerlinCfg* initPerlinCfg(long seed, unsigned long chunkSize, unsigned long scale, unsigned long octaves, float persistence, float lacunarity);
float* PerlinNoiseChunk1D(PerlinCfg* cfg, long chunkIdx);
float* PerlinNoiseChunk2D(PerlinCfg* cfg, long chunkIdx, long chunkIdy);


#endif