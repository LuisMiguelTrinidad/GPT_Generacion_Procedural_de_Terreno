#include "perlin.h"
#include "perlin_utils.h"

// Implementación de la función pública
PerlinGenerator InitPerlinNoise(
    long seed, 
    unsigned long chunkSize, 
    float scale, 
    unsigned long octaves, 
    float persistence, 
    float lacunarity
) {
    return (PerlinGenerator){
        seed,
        chunkSize,
        scale,
        octaves,
        persistence,
        lacunarity
    };
}

inline float fadequintic(float t) {
    return t * t * t * (t*(t*6-15) + 10);
}

inline float fadecubic(float t) {
    return t * t * (3 - 2*t);
}