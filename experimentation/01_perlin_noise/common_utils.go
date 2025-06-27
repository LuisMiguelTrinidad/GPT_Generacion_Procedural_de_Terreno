package main

import (
	"fmt"
	"image"
	"image/color"
	"image/png"
	"log"
	"os"
)

func saveImage(imgArray [][]float32, path string) {
	img := image.NewGray(image.Rect(0, 0, len(imgArray), len(imgArray)))
	for i := range imgArray {
		for j := range len(imgArray[i]) {
			val := uint8((imgArray[i][j] + 1) * 128)
			img.SetGray(i, j, color.Gray{Y: val})
		}
	}

	outFile, err := os.Create(path)
	if err != nil {
		log.Fatal(err)
	}

	defer outFile.Close()
	png.Encode(outFile, img) // Guarda la imagen en formato PNG
}

func export_2d_array_to_ply(chunk [][]float32, scale float32, filename string) {
	// Creamos el archivo o lo resetamos si ya existe
	file, err := os.Create(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	numVertices := len(chunk) * len(chunk[0])
	numFaces := (len(chunk) - 1) * (len(chunk) - 1) * 2 // 2 triángulos por cuadrado

	// HEader
	header := []string{
		"ply",
		"format ascii 1.0",
		"element vertex " + fmt.Sprint(numVertices),
		"property float x",
		"property float y",
		"property float z",
		"element face " + fmt.Sprint(numFaces),
		"property list uchar int vertex_indices",
		"end_header",
	}

	for _, line := range header {
		file.WriteString(line + "\n")
	}

	// Vértices
	for y := range len(chunk) {
		for x := range len(chunk) {
			vertexData := fmt.Sprintf("%d %d %f\n", x, y, chunk[y][x]*scale)
			file.WriteString(vertexData)
		}
	}

	// triángulos
	for y := range len(chunk) - 1 {
		for x := range len(chunk) - 1 {
			// Índices de vértices para el quad actual
			v0 := y*len(chunk) + x
			v1 := y*len(chunk) + (x + 1)
			v2 := (y+1)*len(chunk) + x
			v3 := (y+1)*len(chunk) + (x + 1)

			// Primer triángulo
			fmt.Fprintf(file, "3 %d %d %d\n", v0, v1, v2)
			// Segundo triángulo
			fmt.Fprintf(file, "3 %d %d %d\n", v1, v3, v2)
		}
	}
}
