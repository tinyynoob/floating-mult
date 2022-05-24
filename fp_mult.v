
`timescale 1ns/10ps
module fp_mult(CLK, RESET, ENABLE, DATA_IN, DATA_OUT, READY);
    input CLK, RESET, ENABLE;
    input [7:0] DATA_IN;
    output [7:0] DATA_OUT;
    output READY;

    reg [3:0] incount;
    always @(posedge CLK) begin
        if (RESET)
            incount <= 0;
        else if (ENABLE && incount == 15)
            incount <= 0;
        else if (ENABLE)
            incount <= incount + 1;
    end

    reg inend;
    always @(posedge CLK) begin
        if (RESET)
            inend <= 0;
        else if (incount == 15)
            inend <= 1;
    end
        
    reg [63:0] A;
    always @(posedge CLK) begin
        // no need to reset
        if (ENABLE && !incount[3]) begin
            A <= A << 8;
            A[7:0] <= DATA_IN;
        end
    end

    reg [63:0] B;
    always @(posedge CLK) begin
        // no need to reset
        if (ENABLE && incount[3]) begin
            B <= B << 8;
            B[7:0] <= DATA_IN;
        end
    end

    reg [2:0] calcount; // at calculation stage
    always @(posedge CLK) begin
        if (RESET)
            calcount <= 0;
        else if (inend)
            calcount <= calcount + 1;
    end

    reg calend;
    reg [63:0] Z;
    always @(posedge CLK) begin
        if (RESET) begin
            Z <= 0;
            calend <= 0;
        end
        else if (inend && calcount == 0) begin
            if (A[62:52] == ~11'd0 && A[51:0]) begin
                Z <= A;
                calend <= 1;
            end
            else if (B[62:52] == ~11'd0 && B[51:0]) begin
                Z <= B;
                calend <= 1;
            end
            else if (!A && B[62:52] == ~11'd0 && !B[51:0]) begin
                Z[63] <= A[63] ^ B[63];
                Z[62:52] <= ~11'd0;
                Z[51:0] <= 52'd1;
                calend <= 1;
            end
            else if (!B && A[62:52] == ~11'd0 && !A[51:0]) begin
                Z[63] <= A[63] ^ B[63];
                Z[62:52] <= ~11'd0;
                Z[51:0] <= 52'd1;
                calend <= 1;
            end
            else if (!A || !B) begin
                Z[63] <= A[63] ^ B[63];
                calend <= 1;
                // Z[62:0] <= 63'd0;    originally 0
            end
        end
        else if (!calend && calcount == 3) begin
            Z[12:0] <= A[62:52] + B[62:52]; // temporarily use the space
        end
        else if (!calend && calcount == 4) begin
            Z[12:0] <= Z[12:0] + prod[103];
        end
        // -1023
        // still much to do
        // ...
    end
    
    reg [103:0] prod;   // 104 = 52 + 52
    // cut the multiplication to 4 clock-cycles
    always @(posedge CLK) begin
        if (RESET)
            prod <= 0;
        else if (inend && calcount == 0) begin
            prod <= A * B[12:0];
        end
        else if (!calend && calcount == 1) begin
            prod <= prod + A * {B[25:13], 13'd0};
        end
        else if (!calend && calcount == 2) begin
            prod <= prod + A * {B[38:26], 26'd0};
        end
        else if (!calend && calcount == 3) begin
            prod <= prod + A * {B[51:39], 39'd0};
        end
    end


endmodule