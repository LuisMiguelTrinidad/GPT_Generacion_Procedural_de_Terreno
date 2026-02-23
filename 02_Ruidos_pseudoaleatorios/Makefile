CC = gcc
CFLAGS = -Wall -std=c23 -march=native -flto
LDFLAGS = -lm -lpng
COMMON_FILES = main.c perlin.c

help:
	@echo "Makefile for Perlin Noise implementations"
	@echo "Usage:"
	@echo "  make perlin_test_<variant>   Build the executable using tests/perlin_<variant>.c"
	@echo "  make run_<variant>           Build and run the executable for variant <variant>"
	@echo "  make clean                   Remove generated files"
	@echo "  make version                 Show compiler version"

version:
	$(CC) --version

perlin_test_%:
	mkdir -p bin
	$(CC) $(CFLAGS) -Ofast -o bin/perlin_test_$* $(COMMON_FILES) tests/perlin_$*.c $(LDFLAGS)

run_%: perlin_test_%
	./bin/perlin_test_$*

clean:
	rm -f bin/perlin_test_*
