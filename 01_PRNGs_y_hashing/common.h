#ifndef COMMON_H
#define COMMON_H

#include <stdint.h>
#include <immintrin.h>
/* 
Función para obtener gradiente 2D, aunque sean numeros enteros como entrada, 
los tratamos como uint64_t se usará la notacion en ca2 para los negativos
*/
uint64_t hash(uint64_t seed, int64_t x, int64_t y);

// Macro de utilidad para calcular distancia de Hamming
#define HAMMING_DISTANCE(a, b) __builtin_popcountll(a ^ b)

// Macro para rotación de bits a la derecha/izquierda
#define ROTATE_RIGHT(x, n) __rorq(x, n)
#define ROTATE_LEFT(x, n)  __rolq(x, n)

// Estructura para imágenes RGB
typedef struct {
    uint8_t *data;  // Array de píxeles en formato RGB (r, g, b, r, g, b, ...)
    int width;
    int height;
    int channels; // Debería ser 3 para RGB
} RGBImage;

uint64_t xorshift64(uint64_t state);

// Funciones de manejo de PNG
int save_grayscale_png_uint8(const char *filename, uint8_t *image_data, int chunksize);

#endif // COMMON_H