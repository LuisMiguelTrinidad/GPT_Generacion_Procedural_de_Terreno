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
    PerlinCfg* generator = initPerlinCfg(
        42,         // Semilla
        256,        // Tamaño del chunk
        128,        // Escala
        1,          // Octavas
        2.0f,       // Persistencia
        2.0f        // Lacunaridad
    );
    
    double total_start_time = get_time();
    int total_chunks = 0;
    
    for (int y = 0; y < 16; y++) {
        for (int x = 0; x < 16; x++) {
            double start_time = get_time();
            float* noiseValues2D = PerlinNoiseChunk2D(generator, x, y);
            double end_time = get_time();
            
            double chunk_time = end_time - start_time;
            int chunk_points = generator->chunkSize * generator->chunkSize;
            
            printf("Chunk (%d, %d) generated in %.6f seconds\n", x, y, chunk_time);
            printf("  %d points generated (%.2f million points/sec)\n", 
                   chunk_points, chunk_points / chunk_time / 1000000.0);
            
            free(noiseValues2D);
            total_chunks++;
        }
    }
    
    double total_time = get_time() - total_start_time;
    int total_points = total_chunks * generator->chunkSize * generator->chunkSize;
    
    printf("\nTotal: %d chunks, %d points in %.6f seconds (%.2f million points/sec)\n",
           total_chunks, total_points, total_time, total_points / total_time / 1000000.0);
    
    float* sample_chunk = PerlinNoiseChunk2D(generator, 0, 0);
    save_grayscale_png("perlin_noise_2d.png", sample_chunk, generator->chunkSize);
    free(sample_chunk);
    free(generator->smoothedValues);
    free(generator);
    
    return 0;
}
