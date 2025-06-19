package main

import (
	"math"
	"math/rand"
)

type PerlinGenerator struct {
	chunkSize   uint    // Tamaño del sector a crear
	seed        int64   // Semilla usada
	scale       float32 // Escala a la que reescalar al final
	octaves     uint    // Número de capas de ruido a usar
	persistence uint    // Coef divisor, reduce el peso de cada sucesiva octava de cara al resultado final, (Normalmente 2^Indice_capa)
	lacunarity  uint    // Coef divisor, reduce el periodo (Normalmente 2^Indice_capa))
}

func InitPerlinNoise1D(seed int64, chunkSize uint, scale float32, octaves uint, persistence uint, lacunarity uint) *PerlinGenerator {

	return &PerlinGenerator{
		chunkSize:   chunkSize,
		seed:        seed,
		scale:       scale,
		octaves:     octaves,
		persistence: persistence,
		lacunarity:  lacunarity,
	}
}

func PerlinNoiseChunk1D(config *PerlinGenerator, x int) []float32 {
	chunk := make([]float32, config.chunkSize)

	for oct := range config.octaves {

		actualPeriod := config.chunkSize / uint(math.Pow(float64(config.lacunarity), float64(oct)))

		for sector := range config.chunkSize / actualPeriod {
			slice := PerlinNoise1D(actualPeriod, int(sector)*int(actualPeriod), config.seed)

			red_coeficient := float32(math.Pow(float64(config.persistence), float64(oct)))

			for i := actualPeriod * sector; i < actualPeriod*(sector+1); i++ {
				chunk[i] += slice[i%actualPeriod] / red_coeficient
			}
		}
	}
	return chunk
}

func PerlinNoise1D(period uint, x int, seed int64) []float32 {
	// El periodo determina la distancia entre los vectores generados
	// La x es la coordenada de la casilla inicial del sector a generar, x final será x + amplitud
	// La semilla se usa para el determinismo

	values := make([]float32, period)

	x_0 := getRandomGradient1D(seed, x)
	x_n := getRandomGradient1D(seed, x+int(period))

	//fmt.Printf("Debug: El valor del vector correspondiente a %v es %v\n", x, x_0)
	//fmt.Printf("Debug: El valor del vector correspondiente a %v es %v\n", x+period, x_n)

	for i := range period {
		var x_i float32 = float32(i) / float32(period)

		var lft_value float32 = escProd1D(x_0, x_i)
		var rgt_value float32 = escProd1D(x_i-1, x_n)

		value := smooth(x_i)

		value = lerp1D(lft_value, rgt_value, value)
		//fmt.Printf("Debug: x_i = %v, lft = %v, rgt = %v, val = %v\n", x_i, lft_value, rgt_value, value)
		values[i] = value
	}
	return values
}

func smooth(t float32) float32 {
	return t * t * t * (t*(t*6-15) + 10)
}

func escProd1D(x float32, y float32) float32 {
	return x * y
}

func lerp1D(x_0 float32, x_n float32, x_i float32) float32 {
	return x_0*(1-x_i) + x_n*x_i
}

func getRandomGradient1D(seed int64, x int) float32 {
	r := rand.New(rand.NewSource(seed + int64(x)))
	return r.Float32()*2 - 1
}
