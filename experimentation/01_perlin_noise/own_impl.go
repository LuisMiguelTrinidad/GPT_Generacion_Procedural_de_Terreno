package main

import (
	"math"
	"math/rand"
)

type PerlinGenerator struct {
	chunkSize   uint    // Tamaño del sector a crear
	seed        int64   // Semilla usada
	scale       float32 // Periodo incial
	octaves     uint    // Número de capas de ruido a usar
	persistence float32 // Coef divisor, reduce el peso de cada sucesiva octava de cara al resultado final, (Normalmente 2^Indice_capa)
	lacunarity  float32 // Coef divisor, reduce el periodo (Normalmente 2^Indice_capa))
}

func InitPerlinNoise1D(seed int64, chunkSize uint, scale float32, octaves uint, persistence float32, lacunarity float32) *PerlinGenerator {

	return &PerlinGenerator{
		chunkSize:   chunkSize,
		seed:        seed,
		scale:       scale,
		octaves:     octaves,
		persistence: persistence,
		lacunarity:  lacunarity,
	}
}

func PerlinNoiseChunk1D(cfg *PerlinGenerator, chunkIdx int) []float32 {
	chunk := make([]float32, cfg.chunkSize)

	for octave := range cfg.octaves {
		currentPeriod := cfg.scale / float32(math.Pow(float64(cfg.lacunarity), float64(octave)))
		currentWeight := 1. / float32(math.Pow(float64(cfg.persistence), float64(octave)))
		//fmt.Printf("currentPeriod: %v, currentWeight %v\n", currentPeriod, currentWeight)

		// El punto de inicio es el lugar donde se situa el primer vector
		startPoint := float32(chunkIdx*int(cfg.chunkSize)) / currentPeriod
		endPoint := startPoint + currentPeriod

		x_0 := getRandomGradient1D(cfg.seed, startPoint)
		x_n := getRandomGradient1D(cfg.seed, endPoint)

		//fmt.Printf("Debug: El valor del vector correspondiente a %v es %v\n", x, x_0)
		//fmt.Printf("Debug: El valor del vector correspondiente a %v es %v\n", x+period, x_n)

		for i := range cfg.chunkSize {
			if float32(i) >= endPoint {
				startPoint = endPoint
				endPoint = startPoint + currentPeriod

				x_0 = getRandomGradient1D(cfg.seed, startPoint)
				x_n = getRandomGradient1D(cfg.seed, endPoint)
			}
			var x_i float32 = float32(
				math.Mod(
					float64(int(cfg.chunkSize)*chunkIdx+int(i)),
					float64(currentPeriod)),
			) / currentPeriod

			var lft_value float32 = escProd1D(x_0, x_i)
			var rgt_value float32 = escProd1D(x_i-1, x_n)

			var value float32 = lerp1D(lft_value, rgt_value, x_i)

			//fmt.Printf("Debug: x_i = %v, lft = %v, rgt = %v, val = %v\n", x_i, lft_value, rgt_value, value)
			chunk[i] += value * currentWeight
		}
	}

	return chunk
}

func escProd1D(x float32, y float32) float32 {
	return x * y
}

func lerp1D(x_0 float32, x_n float32, x_i float32) float32 {
	return x_0*(1-x_i) + x_n*x_i
}

func getRandomGradient1D(seed int64, x float32) float32 {
	r := rand.New(rand.NewSource(seed + int64(x)))
	return r.Float32()*2 - 1
}
