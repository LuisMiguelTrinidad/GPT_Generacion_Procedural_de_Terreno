#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "common.h"

#define HAMMING_DISTANCE(a, b) __builtin_popcount(a ^ b)

int avalanche_test(uint64_t number_of_entries, uint64_t random_seed) {
    srand(random_seed);

    // Para la campana gaussiana
    uint64_t s_result[9] = {0,0,0,0,0,0,0,0};
    uint64_t x_result[9] = {0,0,0,0,0,0,0,0};
    uint64_t y_result[9] = {0,0,0,0,0,0,0,0};

    uint64_t s_bit_distribution[64] = {0};
    uint64_t x_bit_distribution[64] = {0};
    uint64_t y_bit_distribution[64] = {0};

    for (uint64_t n = 0; n < number_of_entries; n++) {
        uint64_t x = (uint64_t)rand() << 32 | rand();
        uint64_t y = (uint64_t)rand() << 32 | rand();
        uint64_t s = (uint64_t)rand() << 32 | rand();

        uint64_t g1 = getGradient2D(s, x, y);

        for (int bit_pos = 0; bit_pos < 64; bit_pos++) {
            uint64_t bit_mask = 1ULL << bit_pos;
            
            uint64_t g_s2 = getGradient2D(s ^ bit_mask, x, y);
            uint64_t g_x2 = getGradient2D(s, x ^ bit_mask, y);
            uint64_t g_y2 = getGradient2D(s, x, y ^ bit_mask);
            
            uint8_t hd_s = HAMMING_DISTANCE(g1, g_s2);
            uint8_t hd_x = HAMMING_DISTANCE(g1, g_x2);
            uint8_t hd_y = HAMMING_DISTANCE(g1, g_y2);

            s_result[hd_s]++;
            x_result[hd_x]++;
            y_result[hd_y]++;

            s_bit_distribution[bit_pos] += hd_s;
            x_bit_distribution[bit_pos] += hd_x;
            y_bit_distribution[bit_pos] += hd_y;
        }
    }
    // Imprimir resultados de la distribución de Hamming
    printf("Hamming Distance,      S Count,      X Count,      Y Count\n");
    for (int i = 0; i < 9; i++) {
        printf("%03d, %010lu, %010lu, %010lu", i, s_result[i], x_result[i], y_result[i]);
        if (i % 3 != 2) {
            printf(" | ");
        } else {
            printf("\n");
        }
    }
    
    printf("\nBit Position,  S Hamming Sum,  X Hamming Sum,  Y Hamming Sum\n");
    for (int i = 0; i < 64; i++) {
        printf("%03d, %010lu, %010lu, %010lu", i, s_bit_distribution[i], x_bit_distribution[i], y_bit_distribution[i]);
        if (i % 2 == 0) {
            printf(" | ");
        } else {
            printf("\n");
        }
    }
    return 0;
}

int main() {
    //Correr con 250M de entradas para verificar adecuadamente
    avalanche_test(2500000, 42);
    return 0;
}