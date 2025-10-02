#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#include "common.h"

// Estructura para retornar múltiples valores
typedef struct {
    int32_t counts[256];
    double_t chiSquare;
} uniformity_result;

uniformity_result uniformity_test(uint64_t number_of_entries, uint64_t random_seed) {
    uniformity_result result = {0};
    srand(random_seed);
    
    for (uint64_t n = 0; n < number_of_entries; n++) {
        if ((n & 0xFFFFFF) == 0) {
            printf("Progreso: %lu/%lu (%.2f%%)\n", n, number_of_entries, (double_t)n * 100.0 / (double_t)number_of_entries);
        }
        uint64_t x = (uint64_t)rand() << 32 | rand();
        uint64_t y = (uint64_t)rand() << 32 | rand();
        uint64_t s = (uint64_t)rand() << 32 | rand();
        uint64_t g = getGradient2D(s, x, y);
        result.counts[g]++;
    }

    // Calcular chi-cuadrado
    double_t expected = (double_t)number_of_entries / 256.0;
    result.chiSquare = 0.0;
    for (uint64_t i = 0; i < 256; i++) {
        double_t diff = (double_t)result.counts[i] - expected;
        result.chiSquare += (diff * diff) / expected;
    }

    return result;
}

int main() {
    uniformity_result result = uniformity_test(256e8, 42);
    
    for (int i = 0; i < 256; i++) {
        if (i % 8 == 0 && i != 0) {
            printf("\n");
        }
        printf("%03d: %09d, ", i, result.counts[i]);
    }
    printf("\n");
    printf("Chi-cuadrado: %.2f\n", result.chiSquare);
    
    return 0;
}