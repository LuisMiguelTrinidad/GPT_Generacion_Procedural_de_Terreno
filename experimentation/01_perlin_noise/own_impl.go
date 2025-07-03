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
			var rgt_value float32 = escProd1D(x_n, x_i-1)

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
	fade_x := fadequintic(x_i)
	return x_0*(1-fade_x) + x_n*fade_x
}

func getRandomGradient1D(seed int64, x float32) float32 {
	r := rand.New(rand.NewSource(seed + int64(x)))
	return r.Float32()*2 - 1
}

func PerlinNoiseChunk2Doptimized(cfg *PerlinGenerator, chunkIdx int64, chunkIdy int64) [][]float32 {
	chunk := make([][]float32, cfg.chunkSize)
	for i := range chunk {
		chunk[i] = make([]float32, cfg.chunkSize)
	}

	for octave := range cfg.octaves {
		// Calculamos el periodo y el peso de la octava actual
		var currentPeriod int64 = int64(cfg.scale / float32(math.Pow(float64(cfg.lacunarity), float64(octave))))
		var currentWeight float32 = 1. / float32(math.Pow(float64(cfg.persistence), float64(octave)))

		//Las coordenadas globales son las que definen el cuadrado de puntos con gradientes
		var global_x0 int64 = chunkIdx * int64(cfg.chunkSize) / currentPeriod * currentPeriod
		var global_x1 int64 = global_x0 + currentPeriod
		var global_y0 int64 = chunkIdy * int64(cfg.chunkSize) / currentPeriod * currentPeriod
		var global_y1 int64 = global_y0 + currentPeriod

		for y := int64(0); y < int64(cfg.chunkSize); y++ {
			rev_y := int64(cfg.chunkSize) - 1 - y
			// Si hemos salido del cuadrado que definen los puntos con gradientes por abajo
			if y >= global_y1 {
				global_y0 += currentPeriod
				global_y1 += currentPeriod
			}

			global_x0 = chunkIdx * int64(cfg.chunkSize) / currentPeriod * currentPeriod
			global_x1 = global_x0 + currentPeriod

			// Reseteamos las coordenadas globales de x para cada fila
			gx_0_0, gy_0_0 := getRandomGradient2D(cfg.seed, global_x0, global_y0) // Esquina abajo izq
			gx_1_0, gy_1_0 := getRandomGradient2D(cfg.seed, global_x1, global_y0) // Esquina abajo der
			gx_0_1, gy_0_1 := getRandomGradient2D(cfg.seed, global_x0, global_y1) // Esquina arriba izq
			gx_1_1, gy_1_1 := getRandomGradient2D(cfg.seed, global_x1, global_y1) // Esquina arriba der

			//Hallamos el índice de y en relación con la distancia hacia abajo, operamos asumiendo que empezamos en 0 siempre
			decimalY := float32(y%currentPeriod) / float32(currentPeriod)

			for x := int64(0); x < int64(cfg.chunkSize); x++ {
				// Si hemos salido del cuadrado que definen los puntos con gradientes por la derecha
				if x >= global_x1 {
					global_x0 += currentPeriod
					global_x1 += currentPeriod

					gx_0_0, gy_0_0 = getRandomGradient2D(cfg.seed, global_x0, global_y0) // Esquina abajo izq
					gx_1_0, gy_1_0 = getRandomGradient2D(cfg.seed, global_x1, global_y0) // Esquina abajo der
					gx_0_1, gy_0_1 = getRandomGradient2D(cfg.seed, global_x0, global_y1) // Esquina arriba izq
					gx_1_1, gy_1_1 = getRandomGradient2D(cfg.seed, global_x1, global_y1) // Esquina arriba der
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
				chunk[rev_y][x] += value * currentWeight
			}
		}
	}

	// Normalizamos el chunk para que los valores estén entre -1 y 1
	var max_value float32 = 0.
	for octave := range cfg.octaves {
		max_value += 1. / float32(math.Pow(float64(cfg.persistence), float64(octave)))
	}
	for y := range chunk {
		for x := range chunk[y] {
			chunk[y][x] /= max_value
		}
	}
	return chunk
}

func PerlinNoiseChunk2D(cfg *PerlinGenerator, chunkIdx int64, chunkIdy int64) [][]float32 {
	chunk := make([][]float32, cfg.chunkSize)
	for i := range chunk {
		chunk[i] = make([]float32, cfg.chunkSize)
	}

	for octave := range cfg.octaves {
		// Calculamos el periodo y el peso de la octava actual
		var currentPeriod int64 = int64(cfg.scale / float32(math.Pow(float64(cfg.lacunarity), float64(octave))))
		var currentWeight float32 = 1. / float32(math.Pow(float64(cfg.persistence), float64(octave)))

		//Las coordenadas globales son las que definen el cuadrado de puntos con gradientes
		var global_x0 int64 = chunkIdx * int64(cfg.chunkSize) / currentPeriod * currentPeriod
		var global_x1 int64 = global_x0 + currentPeriod
		var global_y0 int64 = chunkIdy * int64(cfg.chunkSize) / currentPeriod * currentPeriod
		var global_y1 int64 = global_y0 + currentPeriod

		for y := int64(0); y < int64(cfg.chunkSize); y++ {
			rev_y := int64(cfg.chunkSize) - 1 - y
			// Si hemos salido del cuadrado que definen los puntos con gradientes por abajo
			if y >= global_y1 {
				global_y0 += currentPeriod
				global_y1 += currentPeriod
			}

			global_x0 = chunkIdx * int64(cfg.chunkSize) / currentPeriod * currentPeriod
			global_x1 = global_x0 + currentPeriod

			// Reseteamos las coordenadas globales de x para cada fila
			gx_0_0, gy_0_0 := getRandomGradient2Drand(cfg.seed, global_x0, global_y0) // Esquina abajo izq
			gx_1_0, gy_1_0 := getRandomGradient2Drand(cfg.seed, global_x1, global_y0) // Esquina abajo der
			gx_0_1, gy_0_1 := getRandomGradient2Drand(cfg.seed, global_x0, global_y1) // Esquina arriba izq
			gx_1_1, gy_1_1 := getRandomGradient2Drand(cfg.seed, global_x1, global_y1) // Esquina arriba der

			//Hallamos el índice de y en relación con la distancia hacia abajo, operamos asumiendo que empezamos en 0 siempre
			decimalY := float32(y%currentPeriod) / float32(currentPeriod)

			for x := int64(0); x < int64(cfg.chunkSize); x++ {
				// Si hemos salido del cuadrado que definen los puntos con gradientes por la derecha
				if x >= global_x1 {
					global_x0 += currentPeriod
					global_x1 += currentPeriod

					gx_0_0, gy_0_0 = getRandomGradient2Drand(cfg.seed, global_x0, global_y0) // Esquina abajo izq
					gx_1_0, gy_1_0 = getRandomGradient2Drand(cfg.seed, global_x1, global_y0) // Esquina abajo der
					gx_0_1, gy_0_1 = getRandomGradient2Drand(cfg.seed, global_x0, global_y1) // Esquina arriba izq
					gx_1_1, gy_1_1 = getRandomGradient2Drand(cfg.seed, global_x1, global_y1) // Esquina arriba der
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
				chunk[rev_y][x] += value * currentWeight
			}
		}
	}

	// Normalizamos el chunk para que los valores estén entre -1 y 1
	var max_value float32 = 0.
	for octave := range cfg.octaves {
		max_value += 1. / float32(math.Pow(float64(cfg.persistence), float64(octave)))
	}
	for y := range chunk {
		for x := range chunk[y] {
			chunk[y][x] /= max_value
		}
	}
	return chunk
}

// Producto escalar de dos vectores en 2D
func escProd2D(x_0, y_0, x_1, y_1 float32) float32 {
	return (x_0*x_1 + y_0*y_1)
}

// funcion de suavizado, se mueve entre 0 y 1 para valores de t entre 0 y 1
func fadequintic(t float32) float32 {
	return t * t * t * (t*(t*6-15) + 10)
}

func fadecubic(t float32) float32 {
	return t * t * (3 - 2*t)
}

// Interpolación bilineal en 2D,
func lerp2D(b_l, b_r, t_l, t_r, x, y float32) float32 {
	fade_x := fadequintic(x)
	fade_y := fadequintic(y)

	bottom := b_l*(1-fade_x) + b_r*fade_x
	top := t_l*(1-fade_x) + t_r*fade_x
	return bottom*(1-fade_y) + top*fade_y
}

var perlin2Dgradients = [][]float32{
	{0.00000000, -1.41421356}, {0.13861717, -1.40740374}, {0.27589938, -1.38703985}, {0.41052453, -1.35331800},
	{0.54119610, -1.30656296}, {0.66665566, -1.24722501}, {0.78569496, -1.17587560}, {0.89716759, -1.09320187},
	{1.00000000, -1.00000000}, {1.09320187, -0.89716759}, {1.17587560, -0.78569496}, {1.24722501, -0.66665566},
	{1.30656296, -0.54119610}, {1.35331800, -0.41052453}, {1.38703985, -0.27589938}, {1.40740374, -0.13861717},
	{1.41421356, 0.00000000}, {1.40740374, 0.13861717}, {1.38703985, 0.27589938}, {1.35331800, 0.41052453},
	{1.30656296, 0.54119610}, {1.24722501, 0.66665566}, {1.17587560, 0.78569496}, {1.09320187, 0.89716759},
	{1.00000000, 1.00000000}, {0.89716759, 1.09320187}, {0.78569496, 1.17587560}, {0.66665566, 1.24722501},
	{0.54119610, 1.30656296}, {0.41052453, 1.35331800}, {0.27589938, 1.38703985}, {0.13861717, 1.40740374},
	{0.00000000, 1.41421356}, {-0.13861717, 1.40740374}, {-0.27589938, 1.38703985}, {-0.41052453, 1.35331800},
	{-0.54119610, 1.30656296}, {-0.66665566, 1.24722501}, {-0.78569496, 1.17587560}, {-0.89716759, 1.09320187},
	{-1.00000000, 1.00000000}, {-1.09320187, 0.89716759}, {-1.17587560, 0.78569496}, {-1.24722501, 0.66665566},
	{-1.30656296, 0.54119610}, {-1.35331800, 0.41052453}, {-1.38703985, 0.27589938}, {-1.40740374, 0.13861717},
	{-1.41421356, 0.00000000}, {-1.40740374, -0.13861717}, {-1.38703985, -0.27589938}, {-1.35331800, -0.41052453},
	{-1.30656296, -0.54119610}, {-1.24722501, -0.66665566}, {-1.17587560, -0.78569496}, {-1.09320187, -0.89716759},
	{-1.00000000, -1.00000000}, {-0.89716759, -1.09320187}, {-0.78569496, -1.17587560}, {-0.66665566, -1.24722501},
	{-0.54119610, -1.30656296}, {-0.41052453, -1.35331800}, {-0.27589938, -1.38703985}, {-0.13861717, -1.40740374},
}

// Función más ineficiente, usa el paquete "math/rand" para obtener un gradiente aleatorio
func getRandomGradient2Drand(seed int64, x int64, y int64) (float32, float32) {
	// Usar dos generadores aleatorios separados para x e y
	r := rand.New(rand.NewSource(seed + x*83492791 + y*39916801)) // Numeros primos grandes para evitar patrones
	index := r.Intn(64)

	//  Obtener el gradiente correspondiente al índice aleatorio
	grad := perlin2Dgradients[index]

	return grad[0], grad[1]
}

// Función hash mejorada para obtener un gradiente aleatorio en 2D, se puede optimizar más
func getRandomGradient2D(seed int64, x int64, y int64) (float32, float32) {
	// Función hash mejorada con mejor mezcla de bits
	seed ^= x * 83492791 // Número primo grande
	seed ^= y * 39916801 // Número primo grande

	seed = (seed ^ (seed >> 16)) * 19349663
	seed ^= seed >> 32

	gradient := perlin2Dgradients[seed&0x0000003F]

	return gradient[0], gradient[1]
}
