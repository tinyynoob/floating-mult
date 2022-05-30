
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
        
    reg [63:0] A, B;
    reg subnormal;  // if there is subnormal number
    always @(posedge CLK) begin
        // no need to reset
        if (ENABLE && !incount[3]) begin
            A <= A << 8;
            A[7:0] <= DATA_IN;
        end
        else if (inend && !subnormal && !A[62:52] && A[51:0])
        // subnormal number would be swapped to B if there is
            A <= B;
    end

    always @(posedge CLK) begin
        // no need to reset
        if (ENABLE && incount[3]) begin
            B <= B << 8;
            B[7:0] <= DATA_IN;
        end
        else if (inend && !subnormal && !A[62:52] && A[51:0])
            B <= A;
    end

    reg [2:0] calcount; // at calculation stage
    always @(posedge CLK) begin
        if (RESET)
            calcount <= 0;
        else if (inend)
            calcount <= calcount + 1;
    end

    always @(posedge CLK) begin
        if (RESET)
            subnormal <= 0;
        else if (inend && calcount == 0 && 
                    ((!A[62:52] && A[51:0]) || (!B[62:52] && B[51:0])))
            subnormal <= 1;
    end

    reg calend;
    always @(posedge CLK) begin
        if (RESET) begin
            calend <= 0;
        end
        else if (inend && calcount == 0) begin
            // A is NaN
            if (A[62:52] == {11{1'b1}} && A[51:0])
                calend <= 1;
            // B is NaN
            else if (B[62:52] == {11{1'b1}} && B[51:0])
                calend <= 1;
            // A is 0 and B is \infty
            else if (!A[62:0] && B[62:52] == {11{1'b1}} && !B[51:0])
                calend <= 1;
            // B is 0 and A is \infty
            else if (!B[62:0] && A[62:52] == {11{1'b1}} && !A[51:0])
                calend <= 1;
            // A or B is 0 and both not \infty
            else if (!A[62:0] || !B[62:0])
                calend <= 1;
            // A and B are subnormal numbers
            else if (!A[62:52] && A[51:0] && !B[62:52] && B[51:0])
                calend <= 1;
        end
        // still much to do
        // ...
    end


    reg sign;
    always @(posedge CLK) begin
        if (RESET) begin
            sign <= 0;
        end
        else if (inend && calcount == 0) begin
            // A is NaN
            if (A[62:52] == {11{1'b1}} && A[51:0])
                sign <= A[63];
            // B is NaN
            else if (B[62:52] == {11{1'b1}} && B[51:0])
                sign <= B[63];
            // Otherwise
            else
                sign <= A[63] ^ B[63];
        end
    end

    reg [10:0] expn;    // 11-bit
    reg [51:0] frac;    // 52-bit
    always @(posedge CLK) begin
        if (RESET) begin
            expn <= 0;
        end
        else if (inend && calcount == 0) begin
            // A is NaN
            if (A[62:52] == {11{1'b1}} && A[51:0]) begin
                expn <= A[62:52];
            end
            // B is NaN
            else if (B[62:52] == {11{1'b1}} && B[51:0]) begin
                expn <= B[62:52];
            end
            // A is 0 and B is \infty
            else if (!A[62:0] && B[62:52] == {11{1'b1}} && !B[51:0]) begin
                expn <= {11{1'b1}};
            end
            // B is 0 and A is \infty
            else if (!B[62:0] && A[62:52] == {11{1'b1}} && !A[51:0]) begin
                expn <= {11{1'b1}};
            end
            // else
            // expn <= 0
            // no need to set
        end
        // still much to do
        // ...
    end
 
    always @(posedge CLK) begin
        if (RESET) begin
            frac <= 0;
        end
        else if (inend && calcount == 0) begin
            // A is NaN
            if (A[62:52] == {11{1'b1}} && A[51:0]) begin
                frac <= A[51:0];
            end
            // B is NaN
            else if (B[62:52] == {11{1'b1}} && B[51:0]) begin
                frac <= B[51:0];
            end
            // A is 0 and B is \infty
            else if (!A[62:0] && B[62:52] == {11{1'b1}} && !B[51:0]) begin
                frac[0] <= 1;
            end
            // B is 0 and A is \infty
            else if (!B[62:0] && A[62:52] == {11{1'b1}} && !A[51:0]) begin
                frac[0] <= 1;
            end
            // else
            // frac <= 0
            // no need to set
        end
        // still much to do
        // ...
    end
 
    
    reg [105:0] mprod;   // 106 = 2 * (52 + 1)
    // divide the multiplication to 4 clock-cycles
    always @(posedge CLK) begin
        // no need to reset
        // starting multiplication after possibly swap
        if (!calend && calcount == 1) begin
            mprod <= A * B[13:0];
        end
        else if (!calend && calcount == 2) begin
            mprod <= mprod + A * {B[26:14], 14'd0};
        end
        else if (!calend && calcount == 3) begin
            mprod <= mprod + A * {B[39:27], 27'd0};
        end
        else if (!calend && calcount == 4) begin
            mprod <= mprod + A * {~subnormal, B[51:40], 40'd0};
        end
    end


endmodule