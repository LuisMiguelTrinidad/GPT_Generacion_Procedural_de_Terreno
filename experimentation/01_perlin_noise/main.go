package main

func main() {
	imgArray1 := testPerlinNoiseExtPkgImpl(42, 0, 0)
	saveImage(imgArray1, "results/ext_pkg_impl.png")
}
