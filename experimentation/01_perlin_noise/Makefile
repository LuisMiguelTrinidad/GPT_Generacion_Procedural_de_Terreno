CC = gcc
CFLAGS = -Wall -std=c23 -march=native
LDFLAGS = -lm -lpng

# Lista de tests
TESTS = uniformity avalanche pattern

# Comando principal que ejecuta todos los tests
all: $(TESTS)

# Regla genérica para todos los tests
$(TESTS): %: test_%.c
	$(CC) -fopenmp $(CFLAGS) -Ofast -o $@_test common.c $< $(LDFLAGS)
	./$@_test
	rm -f $@_test

# Declarar targets que no son archivos
.PHONY: all $(TESTS)