package main

import (
	"math"
	"math/rand"
)

type PerlinGenerator struct {
	chunkSize   uint    // Tamaño del sector a crear
	seed        int64   // Semilla usada
	scale       float32 // Escala a la que reescalar al final
	octaves     uint8   // Número de capas de ruido a usar
	persistence float32 // Coef mult, reduce el peso de cada sucesiva octava de cara al resultado final, (Normalmente 0.5^Indice_capa)
	lacunarity  float32 // Coef mult, reduce el periodo (Normalmente 0.5^Indice_capa))
}

func InitPerlinNoise1D(seed int64, chunkSize uint, scale float32, octaves uint8, persistence float32, lacunarity float32) *PerlinGenerator {

	return &PerlinGenerator{
		chunkSize:   chunkSize,
		seed:        seed,
		scale:       scale,
		octaves:     octaves,
		persistence: persistence,
		lacunarity:  lacunarity,
	}
}

func PerlinNoiseChunk1D(config *PerlinGenerator, x int) float64 {
	chunk := make([]float32, config.chunkSize)

	for oct := range config.octaves {

		actualAmplitude := float64(config.chunkSize) / math.Pow(2, float64(config.lacunarity))

		for j := range int(float64(config.octaves) / actualAmplitude) {

		}
	}
	return 0.0
}

func PerlinNoise1D(period int, x int, seed int64) []float32 {
	// El periodo determina la distancia entre los vectores generados
	// La x es la coordenada de la casilla inicial del sector a generar, x final será x + amplitud
	// La semilla se usa para el determinismo

	values := make([]float32, period)

	x_0 := getRandomGradient1D(seed, x)
	x_n := getRandomGradient1D(seed, x+period)

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
