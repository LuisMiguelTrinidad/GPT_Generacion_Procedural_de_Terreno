#ifndef PERLIN_H
#define PERLIN_H

typedef struct {
    long long       seed;
    unsigned long   chunkSize;
    float           scale;
    unsigned long   octaves;
    float           persistence;
    float           lacunarity;
} PerlinGenerator;

PerlinGenerator InitPerlinNoise(
    long seed, 
    unsigned long chunkSize, 
    float scale, 
    unsigned long octaves, 
    float persistence, 
    float lacunarity
);

float*  PerlinNoise1D(PerlinGenerator* cfg, long chunkIdx);
float** PerlinNoiseChunk2D(PerlinGenerator* cfg, long chunkIdx, long chunkIdy);


#endif