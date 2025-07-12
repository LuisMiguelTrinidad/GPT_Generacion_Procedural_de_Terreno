#include <stdio.h>
#include <stdlib.h>
#include "perlin.h"

int main() {
    // Configuración básica del generador
    PerlinGenerator generator = InitPerlinNoise(
        42,     // Semilla
        256,    // Tamaño del chunk
        128.0f, // Escala
        8,      // Octavas
        2.0f,   // Persistencia
        2.0f    // Lacunaridad
    );
    
    // Generar ruido Perlin 1D
    float* noiseValues = PerlinNoise1D(&generator, 1);
    
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