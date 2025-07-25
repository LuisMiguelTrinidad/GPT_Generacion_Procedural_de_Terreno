CC = gcc
CFLAGS = -Wall -std=c99 -O3
LDFLAGS = -lm -lpng
FILES = main.c perlin1d.c perlin2d.c

build: 
	$(CC) $(CFLAGS) -o perlin_test $(FILES) $(LDFLAGS)

clean:
	rm -f perlin_test

run: build
	./perlin_test