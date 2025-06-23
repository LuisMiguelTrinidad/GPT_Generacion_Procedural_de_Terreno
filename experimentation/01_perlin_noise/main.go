package main

func main() {
	/*
		imgArray1 := testPerlinNoiseExtPkgImpl(42, 0, 0)
		saveImage(imgArray1, "results/ext_pkg_impl.png")
	*/
	//Custom implementation
	a := InitPerlinNoise(0, 1024, 512, 8, 2, 2)
	//fmt.Printf("%v\n", PerlinNoiseChunk1D(a, 0))
	imgArray2 := PerlinNoiseChunk2D(a, 0, 0)
	/*
		for i := range len(imgArray2) {
			fmt.Printf("%v\n", imgArray2[i])
		}
	*/
	saveImage(imgArray2, "results/cus_pkg_impl.png")
}
