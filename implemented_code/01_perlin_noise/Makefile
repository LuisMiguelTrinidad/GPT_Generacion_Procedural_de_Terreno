CC = gcc
CFLAGS = -Wall -std=c23 -march=native
LDFLAGS = -lm -lpng
PROFILE_FLAGS = -pg
COMMON_FILES = main.c perlin.c

help:
	@echo "Makefile for Perlin Noise implementations"
	@echo "Usage:"
	@echo "  make build_O<level>        Build the executable with optimization level <level> (0-5)"
	@echo "  make run_O<level>          Run the executable with optimization level <level> (0-5)"
	@echo "  make profile_O<level>      Profile the executable with optimization level <level> (0-5)"
	@echo "  make benchmark_O<level>    Benchmark the executable with optimization level0<level> (0-5)"
	@echo "  make clean                 Remove all generated files"
	@echo "  make version               Show compiler version"

version:
	$(CC) --version

perlin_test_%:
	$(CC) $(CFLAGS) -Ofast -o $@ $(COMMON_FILES) perlin2d_$*.c $(LDFLAGS)

run_%: perlin_test_%
	./perlin_test_$*
	rm -f perlin_test_$*

clean:
	rm -f perlin_test_* perlin_profile_* analysis_perlin_*.txt gmon.out

profile_%:
	$(CC) $(CFLAGS) $(PROFILE_FLAGS) -o perlin_profile_$* $(COMMON_FILES) perlin2d_$*.c $(LDFLAGS)
	./perlin_profile_$*
	@for i in $$(seq 1 10); do \
		echo "WarmUp $$i/10"; \
		./perlin_profile_$*; \
	done
    
	./perlin_profile_$*;
	mv gmon.out gmon.sum

	@for i in $$(seq 1 10); do \
		echo "Run $$i/10"; \
		./perlin_profile_$*; \
		gprof -s perlin_profile_$* gmon.out gmon.sum; \
	done

	gprof -p perlin_profile_$* gmon.out > analysis_perlin_$*.txt
	rm -f gmon.out perlin_profile_$*

benchmark_%: perlin_test_%
	@echo "Starting benchmark for perlin2d_$*..."
	@echo "Warming up..."
	@for i in $$(seq 1 5); do \
		echo "WarmUp $$i/5"; \
		./perlin_test_$*; \
	done

	@echo "Running benchmark..."
	@for i in $$(seq 1 10); do \
		./perlin_test_$*; \
	done
    
	@rm -f perlin_test_$*
