#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <omp.h>

#include "../common.h"

void run_avalanche_64b(uint64_t number_of_entries, uint64_t random_seed) {
    // Resultados globales
    // Hamming distance puede ser de 0 a 64 (65 buckets)
    uint64_t s_result[65] = {0};
    uint64_t x_result[65] = {0};
    uint64_t y_result[65] = {0};

    // SAC Matrix: [InputBit 0-63][OutputBit 0-63]
    uint64_t s_sac[64][64] = {0};
    uint64_t x_sac[64][64] = {0};
    uint64_t y_sac[64][64] = {0};

    #pragma omp parallel
    {
        uint64_t rng_state = random_seed ^ (omp_get_thread_num() + 1) ^ 0x9E3779B97F4A7C15;

        uint64_t local_s_result[65] = {0};
        uint64_t local_x_result[65] = {0};
        uint64_t local_y_result[65] = {0};

        uint64_t local_s_sac[64][64] = {0};
        uint64_t local_x_sac[64][64] = {0};
        uint64_t local_y_sac[64][64] = {0};

        #pragma omp for
        for (uint64_t n = 0; n < number_of_entries; n++) {
            rng_state = xorshift64(rng_state);
            uint64_t x = rng_state;

            rng_state = xorshift64(rng_state);
            uint64_t y = rng_state;

            rng_state = xorshift64(rng_state);
            uint64_t s = rng_state;

            uint64_t g1 = hash(s, x, y);

            #pragma omp simd
            for (int bit_pos = 0; bit_pos < 64; bit_pos++) {
                uint64_t bit_mask = 1ULL << bit_pos;
                
                uint64_t g_s2 = hash(s ^ bit_mask, x, y);
                uint64_t g_x2 = hash(s, x ^ bit_mask, y);
                uint64_t g_y2 = hash(s, x, y ^ bit_mask);
                
                uint64_t diff_s = g1 ^ g_s2;
                uint64_t diff_x = g1 ^ g_x2;
                uint64_t diff_y = g1 ^ g_y2;

                local_s_result[__builtin_popcountl(diff_s)]++;
                local_x_result[__builtin_popcountl(diff_x)]++;
                local_y_result[__builtin_popcountl(diff_y)]++;
                

                #pragma omp unroll
                for(int j = 0; j < 64; j++) {
                    local_s_sac[bit_pos][j] += ((diff_s >> j) & 1);
                    local_x_sac[bit_pos][j] += ((diff_x >> j) & 1);
                    local_y_sac[bit_pos][j] += ((diff_y >> j) & 1);
                }
            }
        }

        #pragma omp critical
        {
            for (int i = 0; i < 65; i++) {
                s_result[i] += local_s_result[i];
                x_result[i] += local_x_result[i];
                y_result[i] += local_y_result[i];
            }
            for (int i = 0; i < 64; i++) {
                for (int j = 0; j < 64; j++) {
                    s_sac[i][j] += local_s_sac[i][j];
                    x_sac[i][j] += local_x_sac[i][j];
                    y_sac[i][j] += local_y_sac[i][j];
                }
            }
        }
    }

    for (int i = 0; i < 65; i++) {
        printf("%03d, %012lu, %012lu, %012lu\n", i, s_result[i], x_result[i], y_result[i]);
    }

    printf("\n");
    
    // Output SAC compatible con regex
    for (int i = 0; i < 64; i++) {
        uint64_t s_sum = 0, x_sum = 0, y_sum = 0;
        for (int j = 0; j < 64; j++) {
            s_sum += s_sac[i][j];
            x_sum += x_sac[i][j];
            y_sum += y_sac[i][j];
        }

        printf("%03d: %012lu, %012lu, %012lu | ", i, s_sum, x_sum, y_sum);
        
        printf("S[");
        for(int j=0; j<64; j++) printf("%lu%s", s_sac[i][j], j==63 ? "" : ",");
        printf("] X[");
        for(int j=0; j<64; j++) printf("%lu%s", x_sac[i][j], j==63 ? "" : ",");
        printf("] Y[");
        for(int j=0; j<64; j++) printf("%lu%s", y_sac[i][j], j==63 ? "" : ",");
        printf("]\n");
    }
}

int main(int argc, char *argv[]) {
    if(argc < 3) return 1;
    uint64_t number_of_entries = atoll(argv[1]);
    uint64_t random_seed = atoll(argv[2]);

    run_avalanche_64b(number_of_entries, random_seed);

    return 0;
}
