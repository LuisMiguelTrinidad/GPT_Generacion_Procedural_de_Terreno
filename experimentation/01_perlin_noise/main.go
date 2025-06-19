package main

import "fmt"

func main() {
	imgArray1 := testPerlinNoiseExtPkgImpl(42, 0, 0)
	saveImage(imgArray1, "results/ext_pkg_impl.png")

	//Custom implementation
	a := InitPerlinNoise1D(0, 256, 256, 6, 2, 2)

	fmt.Printf("%v\n", PerlinNoiseChunk1D(a, 0))
}
