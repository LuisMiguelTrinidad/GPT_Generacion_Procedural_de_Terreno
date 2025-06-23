package main

import (
	"image"
	"image/color"
	"image/png"
	"log"
	"os"
)

const chunkSize = 1024

func saveImage(imgArray [][]float32, path string) {
	img := image.NewGray(image.Rect(0, 0, len(imgArray), len(imgArray)))
	for i := 0; i < len(imgArray); i++ {
		for j := 0; j < len(imgArray[i]); j++ {
			val := uint8((imgArray[i][j] + 1) * 128)
			img.SetGray(i, j, color.Gray{Y: val})
		}
	}

	outFile, err := os.Create(path)
	if err != nil {
		log.Fatal(err)
	}

	defer outFile.Close()
	png.Encode(outFile, img) // Save the image as PNG
}
