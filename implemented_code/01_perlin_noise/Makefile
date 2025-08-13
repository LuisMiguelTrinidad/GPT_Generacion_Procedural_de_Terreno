CC = gcc
CFLAGS = -Wall -std=c99 -march=native
LDFLAGS = -lm -lpng
PROFILE_FLAGS = -pg
COMMON_FILES = main.c perlin1d.c

# Generic build rule that requires optimization level
build_%:
	$(CC) $(CFLAGS) -Ofast -o perlin_test_$* $(COMMON_FILES) perlin2d_$*.c $(LDFLAGS)

# Generic run rule that requires optimization level
run_%: build_%
	./perlin_test_$*
	rm -f perlin_test_$*

clean:
	rm -f perlin_test_* perlin_profile_* analysis_perlin_*.txt gmon.out

# Generic profile rule
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

benchmark_%: build_%
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
