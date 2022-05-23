cc = gcc
cflags = -Wall


.PHONY: run checkc clean

checkc: mult_checkc
	./$<

mult_checkc: checkc.c mult.c double.h
	$(cc) -o $@ $^ $(cflags)

mult: mult.c double.h
	$(cc) -o $@ $< $(cflags)

clean:
	-rm mult mult_checkc