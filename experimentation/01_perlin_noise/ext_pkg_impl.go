package main

import (
	"github.com/aquilax/go-perlin"
)

func testPerlinNoiseExtPkgImpl(seed int64, x int, y int) [chunkSize][chunkSize]uint8 {
	alpha := 2.
	beta := 2.
	n := int32(6)

	perlinNoise := perlin.NewPerlin(alpha, beta, n, seed)

	x_float := float64(x)
	y_float := float64(y)

	imgArray := [chunkSize][chunkSize]uint8{}
	for i := 0.; i < chunkSize; i++ {
		for j := 0.; j < chunkSize; j++ {
			noise := perlinNoise.Noise2D(x_float+i/chunkSize, y_float+j/chunkSize)
			imgArray[uint(i)][uint(j)] = uint8((noise + 1) * 128)
		}
	}
	return imgArray
}
