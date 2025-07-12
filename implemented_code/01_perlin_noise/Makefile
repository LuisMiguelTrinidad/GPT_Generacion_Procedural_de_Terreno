CC = gcc
CFLAGS = -Wall -std=c99 -O3
LDFLAGS = -lm
FILES = main.c perlin1d.c perlin2d.c perlin_utils.c

build: 
	$(CC) $(CFLAGS) -o perlin_test $(FILES) $(LDFLAGS)

clean:
	rm -f perlin_test

run: build
	./perlin_test