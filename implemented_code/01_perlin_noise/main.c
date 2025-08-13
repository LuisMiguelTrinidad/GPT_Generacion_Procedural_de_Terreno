#define _POSIX_C_SOURCE 199309L
#include "perlin.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <png.h>


double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1000000000.0;
}

int save_grayscale_png(const char *filename, float *image_data, int chunksize) {
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

    unsigned char *byte_data = (unsigned char*)malloc(chunksize * chunksize * sizeof(unsigned char));
    png_bytep *row_pointers = (png_bytep*)malloc(chunksize * sizeof(png_bytep));
    
    if (!byte_data || !row_pointers) {
        fprintf(stderr, "Error: Could not allocate memory\n");
        if (byte_data) free(byte_data);
        if (row_pointers) free(row_pointers);
        png_destroy_write_struct(&png_ptr, &info_ptr);
        fclose(fp);
        return 1;
    }

    for (int y = 0; y < chunksize; y++) {
        row_pointers[y] = &byte_data[y * chunksize];
        
        for (int x = 0; x < chunksize; x++) {
            float noise_value = image_data[y * chunksize + x];
            
            float normalized_value = (noise_value + 1.0f) * 0.5f;
            
            if (normalized_value < 0.0f) normalized_value = 0.0f;
            if (normalized_value > 1.0f) normalized_value = 1.0f;
            
            // Convert to 8-bit grayscale [0, 255]
            byte_data[y * chunksize + x] = (unsigned char)(normalized_value * 255.0f);
        }
    }

    // Write image data
    png_write_image(png_ptr, row_pointers);

    // End write
    png_write_end(png_ptr, NULL);

    // Clean up
    free(byte_data);
    free(row_pointers);
    png_destroy_write_struct(&png_ptr, &info_ptr);
    fclose(fp);
    return 0;
}

int main() {
    // Configuración básica del generador
    PerlinCfg* generator = initPerlinCfg(
        42,         // Semilla
        512,        // Tamaño del chunk
        128,        // Escala
        1,          // Octavas
        2.0f,       // Persistencia
        2.0f        // Lacunaridad
    );
    /*
    // Generar ruido Perlin 1D
    float* noiseValues = PerlinNoiseChunk1D(&generator, 1);
    
    for (int i = 0; i < generator.chunkSize; i++) {
        int numStars = (int)((noiseValues[i] + 1.0f) * 50.0f);
        
        printf("[%4d]: %6.4f ", i, noiseValues[i]);
        
        for (int j = 0; j < numStars; j++) {
            printf("*");
        }
        printf("\n");
    }
    free(noiseValues);
    */

    // Generar ruido Perlin 2D
    double start_time = get_time();
    float* noiseValues2D = PerlinNoiseChunk2D(generator, 0, 1);
    double end_time = get_time();
    printf("2D Perlin noise generated in %.3f seconds\n", end_time - start_time);
    int total_points = generator->chunkSize * generator->chunkSize * generator->octaves;
    double points_per_second = total_points / (end_time - start_time);
    printf("%d points generated in %.8f seconds (%.4f million points/sec)\n", 
           total_points, end_time - start_time, points_per_second / 1000000.0);


    save_grayscale_png("perlin_noise_2d.png", noiseValues2D, generator->chunkSize);

    free(noiseValues2D);
    return 0;
}
