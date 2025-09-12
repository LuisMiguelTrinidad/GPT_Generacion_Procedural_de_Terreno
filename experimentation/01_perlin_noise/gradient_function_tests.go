package main

import (
	"fmt"
	"math/rand"
)

func getGradient2D(seed int, x int, y int) uint8 {
	seed ^= (x * 0x34A842AF1170EA0 >> 24) ^ (y * 0xAB0954AB5944F80 >> 24) ^ (seed * 0xDC5BBD7BFE17580 >> 24)
	seed ^= seed >> 32

	return uint8(seed & 255)
}

// Retornamos el conteo de cada gradiente y el valor chi-cuadrado
func test_uniformidad(number_of_entries int, random_seed int) ([]int32, float64) {
	rand.New(rand.NewSource(int64(random_seed)))
	counts := make([]int32, 256)
	for n := range number_of_entries {
		if n%1_000_000 == 0 {
			fmt.Printf("Progreso: %d/%d (%.2f%%)\n", n, number_of_entries, float64(n)*100.0/float64(number_of_entries))
		}
		x := rand.Int()
		y := rand.Int()
		seed := rand.Int()
		g := getGradient2D(seed, x, y)
		counts[g]++
	}

	// Calcular chi-cuadrado
	expected := float64(number_of_entries) / 256.0
	chiSquare := 0.0
	for _, count := range counts {
		diff := float64(count) - expected
		chiSquare += (diff * diff) / expected
	}

	return counts, chiSquare
}

func main() {
	counts, chiSquare := test_uniformidad(256*100_000_000, 42)
	for i := 0; i < 256; i++ {
		if i%8 == 0 && i != 0 {
			fmt.Println()
		}
		fmt.Printf("%03d: %08d, ", i, counts[i])
	}
	fmt.Println()
	fmt.Printf("Chi-cuadrado: %.2f\n", chiSquare)
}
