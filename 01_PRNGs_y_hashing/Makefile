CC = gcc
CFLAGS = -Wall -std=c23 -march=native -mbmi2
LDFLAGS = -lm -lpng

TESTS = uniformity avalanche pattern image

all: $(TESTS)

$(TESTS): %: tests/test_%.c
	$(CC) -fopenmp $(CFLAGS) -Ofast -flto -o $@_test common.c $< $(LDFLAGS)
	./$@_test
	rm -f $@_test

compile_%: tests/test_%.c
	mkdir -p ./bin
	$(CC) -fopenmp $(CFLAGS) -Ofast -o ./bin/$* common.c $< $(LDFLAGS)

.PHONY: all $(TESTS) rotation_sweep