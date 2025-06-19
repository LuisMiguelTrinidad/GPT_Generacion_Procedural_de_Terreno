package main

import "fmt"

func main() {
	imgArray1 := testPerlinNoiseExtPkgImpl(42, 0, 0)
	saveImage(imgArray1, "results/ext_pkg_impl.png")

	//Custom implementation
	InitPerlinNoise1D(0, 256, 256, 6, 0.5, 2)
	fmt.Printf("%v\n", PerlinNoise1D(32, 0, 42))
	fmt.Printf("%v\n", PerlinNoise1D(32, 32, 42))
	fmt.Printf("%v\n", PerlinNoise1D(32, 64, 42))
	fmt.Printf("%v\n", PerlinNoise1D(32, 96, 42))
	fmt.Printf("%v\n", PerlinNoise1D(32, 128, 42))
	fmt.Printf("%v\n", PerlinNoise1D(32, 160, 42))
	fmt.Printf("%v\n", PerlinNoise1D(32, 192, 42))
	fmt.Printf("%v\n", PerlinNoise1D(32, 224, 42))
}
