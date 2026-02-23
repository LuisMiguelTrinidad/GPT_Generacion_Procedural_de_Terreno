#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "../common.h"

int pattern_test(int64_t s, int64_t x, int64_t y, uint64_t size, const char* out_dir) {
    uint8_t* x_y_png_array = malloc(sizeof(uint8_t) * size * size);
    uint8_t* x_s_png_array = malloc(sizeof(uint8_t) * size * size);
    uint8_t* s_y_png_array = malloc(sizeof(uint8_t) * size * size);
    
    for (uint64_t i = 0; i < size; i++) {
        for (uint64_t j = 0; j < size; j++) {
            // Pattern XY: i=y, j=x
            uint64_t x_abs = x + j;
            uint64_t y_abs = y + i;
            uint64_t g_xy = hash(s, x_abs, y_abs);
            // Tomamos los 8 bits más significativos para visualizar la estructura global
            x_y_png_array[(size - 1 - i) * size + j] = (uint8_t)(g_xy >> 56);
            
            // Pattern XS: i=s, j=x
            uint64_t s_abs = s + i;
            x_abs = x + j;
            uint64_t g_xs = hash(s_abs, x_abs, y);
            x_s_png_array[(size - 1 - i) * size + j] = (uint8_t)(g_xs >> 56);
            
            // Pattern SY: i=y, j=s
            s_abs = s + j;
            y_abs = y + i;
            uint64_t g_sy = hash(s_abs, x, y_abs);
            s_y_png_array[(size - 1 - i) * size + j] = (uint8_t)(g_sy >> 56);
        }
    }

    char path_xy[512], path_xs[512], path_sy[512];
    save_grayscale_png_uint8(
        (sprintf(path_xy, "%s/pattern_xy.png", out_dir), path_xy), 
        x_y_png_array, size);
    save_grayscale_png_uint8(
        (sprintf(path_xs, "%s/pattern_xs.png", out_dir), path_xs), 
        x_s_png_array, size);
    save_grayscale_png_uint8(
        (sprintf(path_sy, "%s/pattern_sy.png", out_dir), path_sy), 
        s_y_png_array, size);
    
    free(x_y_png_array);
    free(x_s_png_array);
    free(s_y_png_array);

    return 0;
}

int main(int argc, char *argv[]) {
    if(argc < 6) return 1;
    int64_t s = atoll(argv[1]);
    int64_t x = atoll(argv[2]);
    int64_t y = atoll(argv[3]);
    uint64_t size = atoll(argv[4]);
    const char* out_dir = argv[5];

    pattern_test(s, x, y, size, out_dir);
    return 0;
}
