#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <png.h>

#include "common.h"

uint64_t hash(uint64_t seed, int64_t x, int64_t y) {
	const uint64_t C1 = 0xbf58476d1ce4e5b9; // Wyhash64
	const uint64_t C3 = 0xc4ceb9fe1a85ec53; // MurMurHash3 finalizer

	seed ^= ((uint64_t)x * C1) ^ ((uint64_t)y * C3);

    // Usamos el intrínsico de rotación de bits para evitar pérdidas de entropía
    long long unsigned int hi;
	seed = hi ^ _mulx_u64(ROTATE_RIGHT(seed, 32), seed, &hi);
    seed ^= seed >> 32;
	seed = hi ^ _mulx_u64(ROTATE_RIGHT(seed, 32), seed, &hi);
    seed ^= seed >> 16;
	return seed;
}

// George Marsaglia Xorshift64 (muy rápido y thread-safe)
uint64_t xorshift64(uint64_t state) {
	state ^= state << 13;
	state ^= state >> 7;
	state ^= state << 17;
	return state;
}

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
							 PNG_FILTER_TYPE_DEFAULT);

	png_write_info(png_ptr, info_ptr);

	png_bytep *row_pointers = (png_bytep *)malloc(chunksize * sizeof(png_bytep));

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