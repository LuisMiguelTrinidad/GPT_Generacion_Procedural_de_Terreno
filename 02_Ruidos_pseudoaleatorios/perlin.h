#ifndef PERLIN_H
#define PERLIN_H

#include <stdint.h>
#include <math.h>
#include <immintrin.h>

#define HAMMING_DISTANCE(a, b) __builtin_popcountll(a ^ b)

#define ROTATE_RIGHT(x, n) __rorq(x, n)
#define ROTATE_LEFT(x, n)  __rolq(x, n)

#define PERLIN_TABLE_SIZE 256

typedef struct {
    float x;
    float y;
} Vector2;

extern Vector2 perlin_gradients[PERLIN_TABLE_SIZE];

typedef struct {
    uint64_t seed;
    uint64_t chunk_size;
    uint64_t scale;
    uint64_t octaves;
    float persistence;
    float lacunarity;
    float *values;
    float *smoothed_values;
} PerlinConfig;

float vec2_dot(Vector2 a, Vector2 b);

float bilinear_interp(float bl, float br, float tl, float tr, Vector2 t);

uint8_t hash(uint64_t seed, int64_t x, int64_t y);

Vector2 smoothstep_vec2(Vector2 t);

float smoothstep_scalar(float t);

float fast_fract(float v);

uint64_t fast_mod_pow2(uint64_t v, uint64_t scale_mask);

int save_grayscale_png(const char *filename, float *image_data, int chunksize);

PerlinConfig perlin_init_config(
    uint64_t seed, 
    uint64_t chunk_size, 
    uint64_t scale, 
    uint64_t octaves, 
    float persistence, 
    float lacunarity
);
// Generate noise for a chunk and write results into `out_buffer`.
// `out_buffer` must point to at least cfg.chunk_size * cfg.chunk_size floats.
void perlin_generate_chunk2d(
    PerlinConfig cfg,
    int64_t chunk_x,
    int64_t chunk_y,
    float *out_buffer
);

#endif