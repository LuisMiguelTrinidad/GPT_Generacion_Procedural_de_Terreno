package main

import (
	"image"
	"image/color"
	"image/png"
	"log"
	"os"
)

const chunkSize = 1024

func saveImage(imgArray [chunkSize][chunkSize]uint8, path string) {
	img := image.NewGray(image.Rect(0, 0, chunkSize, chunkSize))
	for i := range chunkSize {
		for j := range chunkSize {
			img.SetGray(i, j, color.Gray{Y: imgArray[i][j]})
		}
	}

	outFile, err := os.Create(path)
	if err != nil {
		log.Fatal(err)
	}

	defer outFile.Close()
	png.Encode(outFile, img) // Save the image as PNG
}
