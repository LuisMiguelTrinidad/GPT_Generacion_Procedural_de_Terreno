package main

import (
	"fmt"
	"time"
)

func main() {
	start_time := time.Now()
	a := InitPerlinNoise(42, 1024, 512, 8, 2, 2)
	//fmt.Printf("%v\n", PerlinNoiseChunk1D(a, 0))
	imgArray2 := PerlinNoiseChunk2D(a, 0, 0)
	elapsed := time.Since(start_time)
	fmt.Printf("Tiempo total = %v, %vM. puntos/s\n", elapsed, float64(1024*1024)/1000000.0/elapsed.Seconds())
	/*
		for i := range len(imgArray2) {
			fmt.Printf("%v\n", imgArray2[i])
		}
	*/
	saveImage(imgArray2, "results/cus_pkg_impl.png")
	export_2d_array_to_ply(imgArray2, 128, "results/cus_pkg_impl.ply")
	//El render 02 está generado usando los parámetros 42, 512, 256, 8, 2, 2
}
