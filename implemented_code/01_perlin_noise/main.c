#include "perlin.h"

#include <stdio.h>
#include <stdlib.h>


int main() {
    // Configuración básica del generador
    PerlinGenerator generator = {
        .seed = 42,             // Semilla
        .chunkSize = 256,       // Tamaño del chunk
        .scale = 128.0f,        // Escala
        .octaves = 8,           // Octavas
        .persistence = 2.0f,    // Persistencia
        .lacunarity = 2.0f      // Lacunaridad
    };
    
    // Generar ruido Perlin 1D
    float* noiseValues = PerlinNoiseChunk1D(&generator, 1);
    
    for (int i = 0; i < generator.chunkSize; i++) {
        int numStars = (int)((noiseValues[i] + 1.0f) * 50.0f);
        
        printf("[%4d]: %6.4f ", i, noiseValues[i]);
        
        // Imprimir estrellas
        for (int j = 0; j < numStars; j++) {
            printf("*");
        }
        printf("\n");
    }
    
    free(noiseValues);
    return 0;
}