#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <png.h>

#include "common.h"

int save_grayscale_png_uint8(const char *filename, uint8_t *image_data, int chunksize) {
    FILE *fp = fopen(filename, "wb");
    if (!fp) {
        fprintf(stderr, "Error: Could not open file %s for writing\n", filename);
        return 1;
    }
    
    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png_ptr) {
        fprintf(stderr, "Error: Could not create PNG write struct\n");
        fclose(fp);
        return 1;
    }

    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (!info_ptr) {
        fprintf(stderr, "Error: Could not create PNG info struct\n");
        png_destroy_write_struct(&png_ptr, NULL);
        fclose(fp);
        return 1;
    }

    if (setjmp(png_jmpbuf(png_ptr))) {
        fprintf(stderr, "Error during PNG creation\n");
        png_destroy_write_struct(&png_ptr, &info_ptr);
        fclose(fp);
        return 1;
    }

    png_init_io(png_ptr, fp);

    // Set PNG header information
    png_set_IHDR(png_ptr, info_ptr, chunksize, chunksize,
        8,
        PNG_COLOR_TYPE_GRAY,
        PNG_INTERLACE_NONE,
        PNG_COMPRESSION_TYPE_DEFAULT,
        PNG_FILTER_TYPE_DEFAULT
    );

    png_write_info(png_ptr, info_ptr);

    png_bytep *row_pointers = (png_bytep*)malloc(chunksize * sizeof(png_bytep));
    
    if (!row_pointers) {
        fprintf(stderr, "Error: Could not allocate memory\n");
        png_destroy_write_struct(&png_ptr, &info_ptr);
        fclose(fp);
        return 1;
    }

    for (int y = 0; y < chunksize; y++) {
        row_pointers[y] = &image_data[y * chunksize];
    }

    // Write image data
    png_write_image(png_ptr, row_pointers);

    // End write
    png_write_end(png_ptr, NULL);

    // Clean up
    free(row_pointers);
    png_destroy_write_struct(&png_ptr, &info_ptr);
    fclose(fp);
    return 0;
}

int pattern_test(int64_t s, int64_t x, int64_t y, uint64_t size) {
    
    uint8_t* x_y_png_array = malloc(sizeof(uint8_t) * size * size);
    uint8_t* x_s_png_array = malloc(sizeof(uint8_t) * size * size);
    uint8_t* s_y_png_array = malloc(sizeof(uint8_t) * size * size);
    
    for (uint64_t i = 0; i < size; i++) {
        for (uint64_t j = 0; j < size; j++) {
            // Pattern XY: i=y, j=x
            uint64_t x_abs = x + j;
            uint64_t y_abs = y + i;
            uint8_t g_xy = getGradient2D(s, x_abs, y_abs);
            x_y_png_array[(size - 1 - i) * size + j] = g_xy;
            
            // Pattern XS: i=s, j=x
            uint64_t s_abs = s + i;
            x_abs = x + j;
            uint8_t g_xs = getGradient2D(s_abs, x_abs, y);
            x_s_png_array[(size - 1 - i) * size + j] = g_xs;
            
            // Pattern SY: i=y, j=s
            s_abs = s + j;
            y_abs = y + i;
            uint8_t g_sy = getGradient2D(s_abs, x, y_abs);
            s_y_png_array[(size - 1 - i) * size + j] = g_sy;
        }
    }
    
    save_grayscale_png_uint8("./results/pattern_xy.png", x_y_png_array, size);
    save_grayscale_png_uint8("./results/pattern_xs.png", x_s_png_array, size);
    save_grayscale_png_uint8("./results/pattern_sy.png", s_y_png_array, size);
    
    free(x_y_png_array);
    free(x_s_png_array);
    free(s_y_png_array);

    return 0;
}

int main() {
    pattern_test(-1,-1,-1,256);
    return 0;
}