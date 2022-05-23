cc = gcc
cflags = -O0

.PHONY: run

run: mult
	./mult

mult: mult.c double.h
	$(cc) -o $@ $< $(cflags)