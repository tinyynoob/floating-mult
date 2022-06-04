`timescale 10ns/100ps
`include "fp_mult.v"

module TEST();
    parameter CASENUM = 10000;
    reg [63:0] x [0:CASENUM - 1];
    reg [63:0] y [0:CASENUM - 1];
    reg [63:0] ref [0:CASENUM - 1];
    reg [63:0] myout;
    reg CLK, RESET, ENABLE;
    reg [7:0] DATA_IN;
    integer index, counter;
    integer errcnt;
    wire READY;
    wire [7:0] DATA_OUT;

    fp_mult m1 (.CLK(CLK), .RESET(RESET), .DATA_IN(DATA_IN), .ENABLE(ENABLE),
                                .DATA_OUT(DATA_OUT), .READY(READY));
    
    always begin
        CLK = ~CLK;
        #1;
    end

    initial begin
        $dumpfile("fp_mult.vcd");
        $dumpvars;

        $readmemh("x_pattern.dat", x);
        $readmemh("y_pattern.dat", y);
        $readmemh("reference.dat", ref);

        errcnt = 0;
        CLK = 0;
        ENABLE = 0;
        for (index = 0; index < CASENUM; index = index + 1) begin
            RESET = 1;
            #2 RESET = 0;
            ENABLE = 1;
            for (counter = 0; counter < 16; counter = counter + 1) begin
                case (counter)
                    0: DATA_IN <= x[index][7:0];
                    1: DATA_IN <= x[index][15:8];
                    2: DATA_IN <= x[index][23:16];
                    3: DATA_IN <= x[index][31:24];
                    4: DATA_IN <= x[index][39:32];
                    5: DATA_IN <= x[index][47:40];
                    6: DATA_IN <= x[index][55:48];
                    7: DATA_IN <= x[index][63:56];
                    8: DATA_IN <= y[index][7:0];
                    9: DATA_IN <= y[index][15:8];
                    10: DATA_IN <= y[index][23:16];
                    11: DATA_IN <= y[index][31:24];
                    12: DATA_IN <= y[index][39:32];
                    13: DATA_IN <= y[index][47:40];
                    14: DATA_IN <= y[index][55:48];
                    15: DATA_IN <= y[index][63:56];
                endcase
                #2;
            end
            ENABLE = 0;
            while (!READY)
                #2;
            // assume the output contiguous
            for (counter = 0; counter < 8; counter = counter + 1) begin
                case (counter)
                    0: myout[7:0] <= DATA_OUT;
                    1: myout[15:8] <= DATA_OUT;
                    2: myout[23:16] <= DATA_OUT;
                    3: myout[31:24] <= DATA_OUT;
                    4: myout[39:32] <= DATA_OUT;
                    5: myout[47:40] <= DATA_OUT;
                    6: myout[55:48] <= DATA_OUT;
                    7: myout[63:56] <= DATA_OUT;
                endcase
                #2;
            end
            if (myout != ref[index]) begin
                $display("%t", $time);
                $display("%b_%b_%b", x[index][63], x[index][62:52], x[index][51:0]);
                $display("%b_%b_%b", y[index][63], y[index][62:52], y[index][51:0]);
                $display("Output of module:");
                $display("%b_%b_%b", myout[63], myout[62:52], myout[51:0]);
                $display("Reference answer:");
                $display("%b_%b_%b\n", ref[index][63], ref[index][62:52], ref[index][51:0]);
                errcnt = errcnt + 1;
            end
        end
    $display("Total error: %d /%d", errcnt, CASENUM);
    $finish;
    end
endmodule