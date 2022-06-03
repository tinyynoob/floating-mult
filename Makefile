cc = gcc
cheader = double.h fls.h ils.h mult.h
cflags = -Wall

verilog = iverilog

.PHONY: run check checkc clean pattern

check: TEST *.dat
	./$<

TEST: TEST.v fp_mult.v
	$(verilog) -o $@ $<

pattern: gen_pattern
	./$<

gen_pattern: gen_pattern.c mult.c $(header)
	$(cc) -o $@ gen_pattern.c mult.c $(cflags)

checkc: mult_checkc
	./$<

mult_checkc: checkc.c mult.c $(cheader)
	$(cc) -o $@ checkc.c mult.c $(cflags)

clean:
	-rm mult_checkc
	-rm gen_pattern
	-rm TEST fp_mult.vcd