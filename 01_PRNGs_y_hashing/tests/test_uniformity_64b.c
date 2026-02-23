#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <omp.h>
#include <string.h>

#include "../common.h"

// Analizamos uniformidad BIT A BIT (64 bits) Y Entropía en ventanas de 16 bits
#define WINDOW_16_SIZE 65536
#define NUM_WINDOWS 4

// Analizamos uniformidad BIT A BIT (64 bits) y en 4 ventanas de 16 bits
void run_samples(uint64_t num_samples, uint64_t *counts, uint64_t *histogram_16b, uint64_t global_seed) {
    #pragma omp parallel
    {
        uint64_t thread_rng = global_seed ^ ((omp_get_thread_num() + 1) * 0x9E3779B97F4A7C15ULL);
        thread_rng = xorshift64(thread_rng);
        
        uint64_t local_counts[64] = {0};
        uint64_t *local_hist = (uint64_t*)calloc(NUM_WINDOWS * WINDOW_16_SIZE, sizeof(uint64_t));

        #pragma omp for
        for (uint64_t i = 0; i < num_samples; i++) {
            thread_rng = xorshift64(thread_rng);
            uint64_t s = thread_rng;
            thread_rng = xorshift64(thread_rng);
            int64_t x = thread_rng;
            thread_rng = xorshift64(thread_rng);
            int64_t y = thread_rng;

            uint64_t val = hash(s, x, y);
            
            #pragma omp simd
            for(int b=0; b<64; b++) {
                local_counts[b] += (val >> b) & 1;
            }
            
            local_hist[0 * WINDOW_16_SIZE + (val & 0xFFFF)]++;
            local_hist[1 * WINDOW_16_SIZE + ((val >> 16) & 0xFFFF)]++;
            local_hist[2 * WINDOW_16_SIZE + ((val >> 32) & 0xFFFF)]++;
            local_hist[3 * WINDOW_16_SIZE + ((val >> 48) & 0xFFFF)]++;
        }
        
        #pragma omp critical
        {
            for(int b=0; b<64; b++) {
                counts[b] += local_counts[b];
            }
            for(int j=0; j < NUM_WINDOWS * WINDOW_16_SIZE; j++) {
                histogram_16b[j] += local_hist[j];
            }
        }
        free(local_hist);
    }
}

// Chi-Cuadrado para una ventana específica (65536 bins)
double chi_square_window(uint64_t *histogram_16b, int window_idx, uint64_t total_samples) {
    if (total_samples == 0) return 0.0;
    double expected = (double)total_samples / (double)WINDOW_16_SIZE;
    double chi2 = 0.0;
    uint64_t *hist = histogram_16b + (window_idx * WINDOW_16_SIZE);
    for (int i = 0; i < WINDOW_16_SIZE; i++) {
        double diff = (double)hist[i] - expected;
        chi2 += (diff * diff);
    }
    return chi2 / expected;
}

// Entropía promediada sobre las 4 ventanas
double entropy_avg_16b(uint64_t *histogram_16b, uint64_t total_samples) {
    if(total_samples == 0) return 0.0;
    double sum_entropy = 0.0;
    for(int w=0; w<NUM_WINDOWS; w++) {
        double w_ent = 0.0;
        uint64_t *hist = histogram_16b + (w * WINDOW_16_SIZE);
        for(int i=0; i<WINDOW_16_SIZE; i++) {
            if(hist[i] > 0) {
                double p = (double)hist[i] / (double)total_samples;
                w_ent -= p * log2(p);
            }
        }
        sum_entropy += w_ent;
    }
    return sum_entropy / (double)NUM_WINDOWS;
}

void test_controller(uint64_t max_samples, uint64_t start_log, double log_factor, uint64_t seed) {
    uint64_t counts[64] = {0}; 
    uint64_t *histogram_16b = (uint64_t*)calloc(NUM_WINDOWS * WINDOW_16_SIZE, sizeof(uint64_t));
    uint64_t total = 0;
    uint64_t start_point = xorshift64(seed);
    
    for (uint64_t i = 0; total < max_samples; i++) {
        uint64_t target = (start_log > max_samples) ? max_samples : start_log;
        if (target <= total) target = total + 1;

        run_samples(target - total, counts, histogram_16b, start_point + i);
        total = target;

        double c0 = chi_square_window(histogram_16b, 0, total);
        double c1 = chi_square_window(histogram_16b, 1, total);
        double c2 = chi_square_window(histogram_16b, 2, total);
        double c3 = chi_square_window(histogram_16b, 3, total);
        double ent = entropy_avg_16b(histogram_16b, total);
        
        printf("{%015lu, %.2f, %.2f, %.2f, %.2f, %.8f}\n", total, c0, c1, c2, c3, ent);

        start_log = (uint64_t)(start_log * log_factor);
        if (start_log <= total) {
            start_log = total + 1;
        }
    }
    
    printf("\n\nDistribución final de bits (frecuencia de 1s):");
    for (int i = 0; i < 64; i++) {
        if ((i & 7) == 0) printf("\n");
        printf("%03d: %012lu, ", i, counts[i]);
    }
    printf("\n");
    free(histogram_16b);
}

int main(int argc, char *argv[]) {
    if(argc < 5) return 1;
    uint64_t num_samples = atoll(argv[1]);
    uint64_t start_log = atoll(argv[2]);
    double log_factor = atof(argv[3]);
    uint64_t seed = atoll(argv[4]);

    test_controller(num_samples, start_log, log_factor, seed);
    return 0;
}

