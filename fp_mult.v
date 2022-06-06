
module fp_mult(CLK, RESET, ENABLE, DATA_IN, DATA_OUT, READY);
    input CLK, RESET, ENABLE;
    input [7:0] DATA_IN;
    output reg [7:0] DATA_OUT;
    output reg READY;

    wire signed [11:0] sign_0x7FF = 12'b0111_1111_1111;
    wire signed sign_zero = 0;

    /* Use gray encoding for counters:
     * 4'b0000   0
     * 4'b0001   1
     * 4'b0011   2
     * 4'b0010   3
     * 4'b0110   4
     * 4'b0111   5
     * 4'b0101   6
     * 4'b0100   7
     * 4'b1100   8
     * 4'b1101   9
     * 4'b1111  10
     * 4'b1110  11
     * 4'b1010  12
     * 4'b1011  13
     * 4'b1001  14
     * 4'b1000  15
     */
    reg [3:0] incount;
    reg inend;  // input-stage end
    reg [3:0] calcount; // calculation-stage counter
    reg calend; // calculation-stage end
    reg [2:0] outcount;
    reg outend;
    reg subnormal;  // if there is subnormal number
    always @(posedge CLK) begin
        if (RESET)
            incount <= 0;
        else if (outend)
            incount <= 0;
        else if (ENABLE) begin
            case (incount)
                4'b0000: incount <= 4'b0001;
                4'b0001: incount <= 4'b0011;
                4'b0011: incount <= 4'b0010;
                4'b0010: incount <= 4'b0110;
                4'b0110: incount <= 4'b0111;
                4'b0111: incount <= 4'b0101;
                4'b0101: incount <= 4'b0100;
                4'b0100: incount <= 4'b1100;
                4'b1100: incount <= 4'b1101;
                4'b1101: incount <= 4'b1111;
                4'b1111: incount <= 4'b1110;
                4'b1110: incount <= 4'b1010;
                4'b1010: incount <= 4'b1011;
                4'b1011: incount <= 4'b1001;
                4'b1001: incount <= 4'b1000;
                4'b1000: incount <= 4'b1000;
            endcase
        end
    end

    always @(posedge CLK) begin
        if (RESET)
            inend <= 0;
        else if (outend)
            inend <= 0;
        else if (incount == 4'b1000)    // 15
            inend <= 1;
    end

    reg [63:0] A, B;
    always @(posedge CLK) begin
        // no need to reset
        if (ENABLE && !incount[3]) begin
            A <= A >> 8;
            A[63:56] <= DATA_IN;
        end
        // subnormal number would be swapped to B if there is
        else if (inend && calcount == 0 && !A[62:52] && A[51:0]) begin
            A <= B;
        end
    end

    always @(posedge CLK) begin
        // no need to reset
        if (ENABLE && incount[3]) begin
            B <= B >> 8;
            B[63:56] <= DATA_IN;
        end
        // subnormal number would be swapped to B if there is
        else if (inend && calcount == 0 && !A[62:52] && A[51:0]) begin
            B <= A;
        end
    end

    always @(posedge CLK) begin
        if (RESET)
            subnormal <= 0;
        else if (outend)
            subnormal <= 0;
        else if (inend && calcount == 0 && 
                    ((!A[62:52] && A[51:0]) || (!B[62:52] && B[51:0])))
            subnormal <= 1;
    end

    always @(posedge CLK) begin
        if (RESET)
            calcount <= 0;
        else if (outend)
            calcount <= 0;
        else if (inend && !calend) begin
            case (calcount)
                4'b0000: calcount <= 4'b0001;
                4'b0001: calcount <= 4'b0011;
                4'b0011: calcount <= 4'b0010;
                4'b0010: calcount <= 4'b0110;
                4'b0110: calcount <= 4'b0111;
                4'b0111: calcount <= 4'b0101;
                4'b0101: calcount <= 4'b0100;
                4'b0100: calcount <= 4'b1100;
                4'b1100: calcount <= 4'b1101;
                4'b1101: calcount <= 4'b1111;
                4'b1111: calcount <= 4'b1110;
                4'b1110: calcount <= 4'b1010;
                4'b1010: calcount <= 4'b1011;
                4'b1011: calcount <= 4'b1001;
                4'b1001: calcount <= 4'b1000;
                4'b1000: calcount <= 4'b1000;
            endcase
        end
    end

    always @(posedge CLK) begin
        if (RESET) begin
            calend <= 0;
        end
        else if (outend) begin
            calend <= 0;
        end
        else if (inend && calcount == 0) begin  // 0
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
            // A and B are both subnormal numbers
            else if (!A[62:52] && A[51:0] && !B[62:52] && B[51:0])
                calend <= 1;
        end
        else if (!calend && calcount == 4'b1101) begin  // 9
            calend <= 1;
        end
    end

    wire [15:0] DEBUG_expn = {{3{expn[12]}}, expn};

    /* Index the MSB of @B[51:0], leftmost = 1, rightmost = 52
     */
    reg [5:0] idxMsb;
    reg [2:0] msb_at_block;
    reg [25:0] tmpbuf;  // temp buffer
    reg [105:0] mprod;   // 106 = 2 * (52 + 1)
    reg signed [12:0] expn;    // 13-bit
    always @(posedge CLK) begin
        // no need to reset
        if (inend && calcount == 0) begin   // 0
            // A is NaN
            if (A[62:52] == {11{1'b1}} && A[51:0])
                mprod[103:52] <= {1'b1, A[50:0]};
            // B is NaN
            else if (B[62:52] == {11{1'b1}} && B[51:0])
                mprod[103:52] <= {1'b1, B[50:0]};
            // A is 0 and B is \infty
            else if (!A[62:0] && B[62:52] == {11{1'b1}} && !B[51:0])
                mprod[103:52] <= 1;
            // B is 0 and A is \infty
            else if (!B[62:0] && A[62:52] == {11{1'b1}} && !A[51:0])
                mprod[103:52] <= 1;
            // A or B is 0 and both not \infty
            else if (!A[62:0] || !B[62:0])
                mprod[103:52] <= 0;
            // A and B are both subnormal numbers
            else if (!A[62:52] && A[51:0] && !B[62:52] && B[51:0])
                mprod[103:52] <= 0;
        end
        // starting multiplication after possibly swap
        // divide the multiplication to 4 clock-cycles
        else if (!calend && calcount == 4'b0001) begin  // 1
            mprod <= {1'b1, A[51:0]} * B[13:0];
        end
        else if (!calend && calcount == 4'b0011) begin  // 2
            mprod <= mprod + (({1'b1, A[51:0]} * B[26:14]) << 14);
        end
        else if (!calend && calcount == 4'b0010) begin  // 3
            mprod <= mprod + (({1'b1, A[51:0]} * B[39:27]) << 27);
        end
        else if (!calend && calcount == 4'b0110) begin  // 4
            mprod <= mprod + (({1'b1, A[51:0]} * {~subnormal, B[51:40]}) << 40);
        end
        // subnormal align
        else if (!calend && calcount == 4'b0111) begin  // 5
            if (subnormal)
                mprod <= mprod << idxMsb;
        end
        else if (!calend && calcount == 4'b0101) begin  // 6
            if (mprod[105])
                mprod <= mprod >> 1;
        end
        // align according to carry and new @expn
        else if (!calend && calcount == 4'b0100) begin  // 7
            if (sign_zero >= expn && expn >= -52)
                mprod <= mprod >> (2 + ~expn);
        end
        // rounding
        else if (!calend && calcount == 4'b1100) begin  // 8
            {mprod[105], mprod[103:52]} <= mprod[103:52] + mprod[51];
        end
        else if (!calend && calcount == 4'b1101) begin  // 9
            if (expn >= sign_0x7FF)
                mprod[103:52] <= 0;
            else if (expn < -52)
                mprod[103:52] <= 0;
        end
    end

    always @(posedge CLK) begin
        // no need to reset
        if (!calend && subnormal && calcount == 4'b0001)    // 1
            msb_at_block[2] <= (B[51:0] >= (1 << 26));
        else if (!calend && subnormal && calcount == 4'b0011)   // 2
            msb_at_block[1] <= (tmpbuf[25:0] >= (1 << 13));
        else if (!calend && subnormal && calcount == 4'b0010)   // 3
            msb_at_block[0] <= (tmpbuf[12:0] >= (1 << 7));
    end

    always @(posedge CLK) begin
        // no need to reset
        if (!calend && subnormal && calcount == 4'b0010)    // 3
            idxMsb <= (2'b11 - msb_at_block[2:1]) * 13;
        else if (!calend && subnormal && calcount == 4'b0110) begin // 4
            if (tmpbuf[6])
                idxMsb <= idxMsb + ({3{~msb_at_block[0]}} & 6) + 1;
            else if (tmpbuf[5])
                idxMsb <= idxMsb + ({3{~msb_at_block[0]}} & 6) + 2;
            else if (tmpbuf[4])
                idxMsb <= idxMsb + ({3{~msb_at_block[0]}} & 6) + 3;
            else if (tmpbuf[3])
                idxMsb <= idxMsb + ({3{~msb_at_block[0]}} & 6) + 4;
            else if (tmpbuf[2])
                idxMsb <= idxMsb + ({3{~msb_at_block[0]}} & 6) + 5;
            else if (tmpbuf[1])
                idxMsb <= idxMsb + ({3{~msb_at_block[0]}} & 6) + 6;
            else
                idxMsb <= idxMsb + ({3{~msb_at_block[0]}} & 6) + 7;
        end
    end

    wire signed [11:0] sign_Aexpn = {1'b0, A[62:52]};
    wire signed [11:0] sign_Bexpn = {1'b0, B[62:52]};
    wire signed [1:0] sign_carry = {1'b0, mprod[105]};
    wire signed [6:0] sign_idxMsb = {1'b0, idxMsb};

    always @(posedge CLK) begin
        // no need to reset
        /* help computing @idxMsb */
        if (!calend && subnormal && calcount == 4'b0001) begin  // 1
            tmpbuf <= (B[51:0] >= (1 << 26)) ? B[51:26] : B[25:0];
        end
        else if (!calend && subnormal && calcount == 4'b0011) begin // 2
            tmpbuf[12:0] <= (tmpbuf[25:0] >= (1 << 13)) ? tmpbuf[25:13] : tmpbuf[12:0];
        end
        else if (!calend && subnormal && calcount == 4'b0010) begin // 3
            if (tmpbuf[12:0] >= (1 << 7))
                tmpbuf[6:0] <= {tmpbuf[12:7], 1'b0};    // padding at right
            else
                tmpbuf[6:0] <= tmpbuf[6:0];
        end
    end

    always @(posedge CLK) begin
        // no reset
        if (inend && calcount == 0) begin
            // A is NaN
            if (A[62:52] == {11{1'b1}} && A[51:0])
                expn[10:0] <= A[62:52];
            // B is NaN
            else if (B[62:52] == {11{1'b1}} && B[51:0])
                expn[10:0] <= B[62:52];
            // A is 0 and B is \infty
            else if (!A[62:0] && B[62:52] == {11{1'b1}} && !B[51:0])
                expn[10:0] <= {11{1'b1}};
            // B is 0 and A is \infty
            else if (!B[62:0] && A[62:52] == {11{1'b1}} && !A[51:0])
                expn[10:0] <= {11{1'b1}};
            // not special case
            else
                expn <= 0;
        end
        else if (!calend && calcount == 4'b0101) begin  // 6
            if (subnormal)
                expn <= sign_Aexpn - 11'd1022 - sign_idxMsb + sign_carry;
            else
                expn <= sign_Aexpn + sign_Bexpn - 11'd1023 + sign_carry;
        end
        else if (!calend && calcount == 4'b1101) begin  // 9
            if (expn >= sign_0x7FF)
                expn[10:0] <= {11{1'b1}};
            else if (expn > sign_zero)
                expn[10:0] <= expn + sign_carry;
            else if (expn >= -52)
                expn[10:0] <= {{9{1'b0}}, sign_carry};
            else
                expn[10:0] <= 0;
        end
    end

    reg sign;
    always @(posedge CLK) begin
        // no need to reset
        if (inend && calcount == 0) begin
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

    always @(posedge CLK) begin
        if (RESET)
            outcount <= 0;
        else if (outend)
            outcount <= 0;
        else if (calend && !outend) begin
            case (outcount)
                3'b000: outcount <= 3'b001;
                3'b001: outcount <= 3'b011;
                3'b011: outcount <= 3'b010;
                3'b010: outcount <= 3'b110;
                3'b110: outcount <= 3'b111;
                3'b111: outcount <= 3'b101;
                3'b101: outcount <= 3'b100;
                3'b100: outcount <= 3'b100;
            endcase
        end
    end

    always @(posedge CLK) begin
        if (RESET)
            outend <= 0;
        else if (outend)
            outend <= 0;
        else if (outcount == 3'b100)    // 7
            outend <= 1;
    end

    always @(posedge CLK) begin
        if (RESET)
            READY <= 0;
        else if (calend && !outend)
            READY <= 1;
        else
            READY <= 0;
    end

    always @(posedge CLK) begin
        // no need to reset
        if (calend && !outend) begin
            case (outcount)
                3'b000: DATA_OUT <= mprod[59:52];
                3'b001: DATA_OUT <= mprod[67:60];
                3'b011: DATA_OUT <= mprod[75:68];
                3'b010: DATA_OUT <= mprod[83:76];
                3'b110: DATA_OUT <= mprod[91:84];
                3'b111: DATA_OUT <= mprod[99:92];
                3'b101: DATA_OUT <= {expn[3:0], mprod[103:100]};
                3'b100: DATA_OUT <= {sign, expn[10:4]};
            endcase
        end
    end
endmodule