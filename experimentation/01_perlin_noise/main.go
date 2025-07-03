package main

import (
	"fmt"
	"time"
)

func main() {
	seed := int64(42)
	width := uint(2048)
	scale := float32(1024)
	octaves := uint(10)
	persistence := float32(2)
	lacunarity := float32(2)

	start_time := time.Now()
	a := InitPerlinNoise(seed, width, scale, octaves, persistence, lacunarity)
	//fmt.Printf("%v\n", PerlinNoiseChunk1D(a, 0))
	imgArray1 := PerlinNoiseChunk2Doptimized(a, 0, 0)
	elapsed := time.Since(start_time)
	fmt.Printf("Tiempo total = %v, %vM. puntos/s\n", elapsed, float64(octaves*width*width)/1e6/elapsed.Seconds())
	//imgArray2 := PerlinNoiseChunk2D(a, 0, 0)
	elapsed2 := time.Since(start_time)
	fmt.Printf("Tiempo total = %v, %vM. puntos/s\n", elapsed2, float64(octaves*width*width)/1e6/elapsed2.Seconds())
	saveImage(imgArray1, "results/cus_pkg_impl_optimized.png")
	//saveImage(imgArray2, "results/cus_pkg_impl.png")
	export_2d_array_to_ply(imgArray1, 2048, "results/cus_pkg_impl_1.ply")
	//export_2d_array_to_ply(imgArray2, 128, "results/cus_pkg_impl_2.ply")
	//El render 02 está generado usando los parámetros 42, 512, 256, 8, 2, 2
}
