#include <stdint.h>
#include "common.h"

#if __STDC_VERSION__ >= 202311L
    #include <stdbit.h>
    #define ROTATE_RIGHT(x, n) __builtin_stdc_rotate_right(x, n)
#else
    #define ROTATE_RIGHT(x, n) (((x) >> (n)) | ((x) << (64 - (n))))
#endif


int getGradient2D(int64_t seed, int64_t x, int64_t y) {
    const uint64_t C1 = 0xbf58476d1ce4e5b9; // Wyhash64
    const uint64_t C2 = 0xff51afd7ed558ccd; // MurMurHash3 finalizer
    const uint64_t C3 = 0xc4ceb9fe1a85ec53; // MurMurHash3 finalizer
    const uint64_t C4 = 0x9e3779b97f4a7c15; // MurMurHash3

    // Abusamos fma para multiplicar y sumar en una sola instruccion
    seed ^= (x * C1 + C3) ^ (y * C2 + C4);
    // Usamos el intrínsico de rotación de bits para evitar pérdidas de entropía
    seed *= seed + C3;
    seed *= ROTATE_RIGHT(seed, 32) + C4;
    seed ^= ROTATE_RIGHT(seed, 32);

    return (uint8_t)(seed & 0xFF);
}