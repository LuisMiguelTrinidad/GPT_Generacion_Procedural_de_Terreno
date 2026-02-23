#define _POSIX_C_SOURCE 199309L
#include "perlin.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <png.h>
#include <omp.h>


double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1000000000.0;
}

int main() {
    PerlinConfig generator = perlin_init_config(
        42,         // Semilla
        256,        // Tamaño del chunk
        64,         // Escala
        1,          // Octavas
        2.0f,       // Persistencia
        2.0f        // Lacunaridad
    );
    
    double total_time = 0;
    uint64_t total_cycles = 0;
    int total_chunks = 0;
    
    // Buffer temporal reutilizable para generación de chunks
    float *noiseValues2D = (float*)malloc(generator.chunk_size * generator.chunk_size * sizeof(float));
    if (!noiseValues2D) {
        fprintf(stderr, "Error: could not allocate noise buffer\n");
        return 1;
    }
    for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 32; x++) {
            perlin_generate_chunk2d(generator, x, y, noiseValues2D);
        }
    }
    
    uint64_t start_cycles = __rdtsc();
    double start_time = get_time();
    for (int y = 0; y < 128; y++) {
        for (int x = 0; x < 128; x++) {
            perlin_generate_chunk2d(generator, x, y, noiseValues2D);
            total_chunks++;
        }
    }
    total_cycles = __rdtsc() - start_cycles;
    total_time = get_time() - start_time;
    
    uint64_t total_points = total_chunks * generator.chunk_size * generator.chunk_size;
    
    printf("\nTotal: %d chunks, %lu millions of points in %.6f seconds\n", total_chunks, total_points / 1000000, total_time);
    printf("Performance: %.6f million points/sec\n", total_points / total_time / 1e6);
    printf("Efficiency:  %.2f cycles/point (Reference Cycles)\n", (double)total_cycles / total_points);

    // 1. Reservar memoria para la imagen completa (3x3 chunks)
    float* compositeNoise = (float*)malloc(generator.chunk_size * generator.chunk_size * 3 * 3 * sizeof(float));
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            perlin_generate_chunk2d(generator, x, y, noiseValues2D);

            // 2. Copiar el chunk a la posición correcta en el buffer compuesto
            // Convertimos x, y (-1, 0, 1) a índices de array (0, 1, 2)
            int startX = (x + 1) * generator.chunk_size;
            int startY = (1 - y) * generator.chunk_size;

            for (int row = 0; row < generator.chunk_size; row++) {
                for (int col = 0; col < generator.chunk_size; col++) {
                    int compositeIdx = (startY + row) * generator.chunk_size * 3 + (startX + col);
                    int chunkIdx = row * generator.chunk_size + col;
                    compositeNoise[compositeIdx] = noiseValues2D[chunkIdx];
                }
            }
            // reuse noiseValues2D buffer
        }
    }

    // 3. Guardar la imagen final compuesta
    save_grayscale_png("output/perlin_composite_3x3.png", compositeNoise, generator.chunk_size * 3);

    // 4. Limpiar memoria
    free(compositeNoise);
    free(generator.smoothed_values);
    free(noiseValues2D);
    
    return 0;
}
