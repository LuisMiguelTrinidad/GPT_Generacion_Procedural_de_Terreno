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

func InitPerlinNoise(seed int64, chunkSize uint, scale float32, octaves uint, persistence float32, lacunarity float32) *PerlinGenerator {

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
			var rgt_value float32 = escProd1D(1-x_i, x_n)

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

func PerlinNoiseChunk2D(cfg *PerlinGenerator, chunkIdx int, chunkIdy int) [][]float32 {
	chunk := make([][]float32, cfg.chunkSize)
	for i := range chunk {
		chunk[i] = make([]float32, cfg.chunkSize)
	}

	for octave := range cfg.octaves {
		// Calculamos el periodo y el peso de la octava actual
		var currentPeriod int = int(cfg.scale / float32(math.Pow(float64(cfg.lacunarity), float64(octave))))
		var currentWeight float32 = 1. / float32(math.Pow(float64(cfg.persistence), float64(octave)))

		var global_x0 int = chunkIdx * int(cfg.chunkSize) / currentPeriod * currentPeriod
		var global_x1 int = global_x0 + currentPeriod
		var global_y0 int = chunkIdy * int(cfg.chunkSize) / currentPeriod * currentPeriod
		var global_y1 int = global_y0 + currentPeriod

		for y := 0; y < int(cfg.chunkSize); y++ {
			// Si hemos salido del cuadrado que definen los puntos con gradientes por abajo
			if y >= global_y1 {
				global_y0 += currentPeriod
				global_y1 += currentPeriod
			}

			global_x0 = chunkIdx * int(cfg.chunkSize) / currentPeriod * currentPeriod
			global_x1 = global_x0 + currentPeriod

			gx_0_0, gy_0_0 := getRandomGradient2D(cfg.seed, float32(global_x0), float32(global_y0)) // Esquina abajo izq
			gx_1_0, gy_1_0 := getRandomGradient2D(cfg.seed, float32(global_x1), float32(global_y0)) // Esquina abajo der
			gx_0_1, gy_0_1 := getRandomGradient2D(cfg.seed, float32(global_x0), float32(global_y1)) // Esquina arriba izq
			gx_1_1, gy_1_1 := getRandomGradient2D(cfg.seed, float32(global_x1), float32(global_y1)) // Esquina arriba der

			//Hallamos el índice de y en relación con la distancia hacia abajo
			decimalY := float32(y%currentPeriod) / float32(currentPeriod)

			for x := 0; x < int(cfg.chunkSize); x++ {
				// Si hemos salido del cuadrado que definen los puntos con gradientes por la derecha
				if x >= global_x1 {
					global_x0 += currentPeriod
					global_x1 += currentPeriod

					gx_0_0, gy_0_0 = getRandomGradient2D(cfg.seed, float32(global_x0), float32(global_y0)) // Esquina abajo izq
					gx_1_0, gy_1_0 = getRandomGradient2D(cfg.seed, float32(global_x1), float32(global_y0)) // Esquina abajo der
					gx_0_1, gy_0_1 = getRandomGradient2D(cfg.seed, float32(global_x0), float32(global_y1)) // Esquina arriba izq
					gx_1_1, gy_1_1 = getRandomGradient2D(cfg.seed, float32(global_x1), float32(global_y1)) // Esquina arriba der
				}

				// Hallamos el índice de x en relación con la distancia hacia la izquierda
				decimalX := float32(x%currentPeriod) / float32(currentPeriod)

				// Obtenemos el valor de cada esquina tras el producto vectorial
				bot_lft_val := escProd2D(gx_0_0, gy_0_0, decimalX, decimalY)
				bot_rgt_val := escProd2D(gx_1_0, gy_1_0, decimalX-1, decimalY)
				top_lft_val := escProd2D(gx_0_1, gy_0_1, decimalX, decimalY-1)
				top_rgt_val := escProd2D(gx_1_1, gy_1_1, decimalX-1, decimalY-1)

				// Interpolamos los valores de las esquinas
				value := lerp2D(bot_lft_val, bot_rgt_val, top_lft_val, top_rgt_val, decimalX, decimalY)
				// Aplicamos la función de suavizado y el peso de la octava actual
				chunk[cfg.chunkSize-uint(y)-1][x] += value * currentWeight
			}
		}
	}

	return chunk
}
func escProd2D(x_0, y_0, x_1, y_1 float32) float32 {
	return (x_0*x_1 + y_0*y_1)
}

func lerp2D(b_l, b_r, t_l, t_r, x, y float32) float32 {
	fade_x := fade2D(x)
	fade_y := fade2D(y)

	bottom := b_l*(1-fade_x) + b_r*fade_x
	top := t_l*(1-fade_x) + t_r*fade_x
	return bottom*(1-fade_y) + top*fade_y
}

func fade2D(t float32) float32 {
	return t * t * t * (t*(t*6-15) + 10)
}

func getRandomGradient2D(seed int64, x float32, y float32) (float32, float32) {
	// Convertir coordenadas a enteros para evitar problemas de precisión flotante
	ix := int64(x)
	iy := int64(y)

	// Usar una función hash más robusta para combinar las coordenadas con la semilla
	// Estos números primos grandes ayudan a distribuir mejor los valores
	hash := seed
	hash = hash*73856093 ^ ix
	hash = hash*19349663 ^ iy
	hash = hash * 83492791

	// Usar el hash como semilla para el generador aleatorio
	r := rand.New(rand.NewSource(hash))

	// En lugar de generar un ángulo aleatorio, usar vectores predefinidos
	// que son más eficientes y dan mejor distribución
	gradients := [][]float32{
		{1, 1}, {-1, 1}, {1, -1}, {-1, -1},
		{1, 0}, {-1, 0}, {0, 1}, {0, -1},
		{0.7071, 0.7071}, {-0.7071, 0.7071},
		{0.7071, -0.7071}, {-0.7071, -0.7071},
	}

	// Seleccionar un gradiente basado en el valor aleatorio
	gradientIndex := r.Intn(len(gradients))
	gradient := gradients[gradientIndex]

	return gradient[0], gradient[1]
}
