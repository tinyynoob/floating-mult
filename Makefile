cc = gcc
cflags = -Wall


.PHONY: run checkc clean

checkc: mult_checkc
	./$<

mult_checkc: checkc.c mult.c double.h
	$(cc) -o $@ checkc.c mult.c $(cflags)

clean:
	-rm mult_checkc