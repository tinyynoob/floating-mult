cc = gcc
cheader = double.h fls.h ils.h mult.h
cflags = -Wall


.PHONY: run checkc clean

checkc: mult_checkc
	./$<

mult_checkc: checkc.c mult.c $(cheader)
	$(cc) -o $@ checkc.c mult.c $(cflags)

clean:
	-rm mult_checkc