
`timescale 10ns/100ps
module fp_mult(CLK, RESET, ENABLE, DATA_IN, DATA_OUT, READY);
    input CLK, RESET, ENABLE;
    input [7:0] DATA_IN;
    output reg [7:0] DATA_OUT;
    output reg READY;

    wire signed [11:0] sign_0x7FF = 12'b0111_1111_1111;
    wire signed sign_zero = 0;

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
        else if (ENABLE && incount == 15)
            incount <= 15;
        else if (ENABLE)
            incount <= incount + 1;
    end

    always @(posedge CLK) begin
        if (RESET)
            inend <= 0;
        else if (outend)
            inend <= 0;
        else if (incount == 15)
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
        else if (inend && !calend)
            calcount <= calcount + 1;
    end

    always @(posedge CLK) begin
        if (RESET) begin
            calend <= 0;
        end
        else if (outend) begin
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
            // A and B are both subnormal numbers
            else if (!A[62:52] && A[51:0] && !B[62:52] && B[51:0])
                calend <= 1;
        end
        else if (!calend && calcount == 9) begin
            calend <= 1;
        end
    end

    /* Index the MSB of @B[51:0], leftmost = 1, rightmost = 52
     */
    reg [5:0] idxMsb;
    reg [2:0] msb_at_block;
    reg [25:0] tmpbuf;  // temp buffer
    reg [105:0] mprod;   // 106 = 2 * (52 + 1)
    reg signed [12:0] expn;    // 13-bit
    always @(posedge CLK) begin
        // no need to reset
        // starting multiplication after possibly swap
        // divide the multiplication to 4 clock-cycles
        if (!calend && calcount == 1) begin
            mprod <= {1'b1, A[51:0]} * B[13:0];
        end
        else if (!calend && calcount == 2) begin
            mprod <= mprod + (({1'b1, A[51:0]} * B[26:14]) << 14);
        end
        else if (!calend && calcount == 3) begin
            mprod <= mprod + (({1'b1, A[51:0]} * B[39:27]) << 27);
        end
        else if (!calend && calcount == 4) begin
            mprod <= mprod + (({1'b1, A[51:0]} * {~subnormal, B[51:40]}) << 40);
        end
        // subnormal align
        else if (!calend && calcount == 5) begin
            if (subnormal)
                mprod <= mprod << idxMsb;
        end
        // align according to carry and new @expn
        else if (!calend && calcount == 6) begin
            if (subnormal) begin
                if (mprod[105] && sign_zero > expn && expn >= -53)
                    mprod <= mprod >> (2 + ~expn);
            end
            else begin
                if (mprod[105] && sign_zero >= expn && expn >= -52)
                    mprod <= mprod >> (3 + ~expn);
                else if (sign_zero >= expn && expn >= -52)
                    mprod <= mprod >> (2 + ~expn);
                else if (mprod[105])
                    mprod <= mprod >> 1;
            end
        end
        // rounding
        else if (!calend && calcount == 7) begin
            {mprod[105], mprod[103:52]} <= mprod[103:52] + mprod[51];
        end
        else if (!calend && calcount == 8) begin
            if (expn >= sign_0x7FF)
                mprod[103:52] <= 0;
            else if (expn < -52)
                mprod[103:52] <= 0;
        end
    end

    always @(posedge CLK) begin
        // no need to reset
        if (!calend && subnormal && calcount == 1)
            msb_at_block[2] <= (B[51:0] >= (1 << 26));
        else if (!calend && subnormal && calcount == 2)
            msb_at_block[1] <= (tmpbuf[25:0] >= (1 << 13));
        else if (!calend && subnormal && calcount == 3)
            msb_at_block[0] <= (tmpbuf[12:0] >= (1 << 7));
    end

    always @(posedge CLK) begin
        // no need to reset
        if (!calend && subnormal && calcount == 3)
            idxMsb <= (2'b11 - msb_at_block[2:1]) * 13;
        else if (!calend && subnormal && calcount == 4) begin
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
        if (!calend && subnormal && calcount == 1) begin
            tmpbuf <= (B[51:0] >= (1 << 26)) ? B[51:26] : B[25:0];
        end
        else if (!calend && subnormal && calcount == 2) begin
            tmpbuf[12:0] <= (tmpbuf[25:0] >= (1 << 13)) ? tmpbuf[25:13] : tmpbuf[12:0];
        end
        else if (!calend && subnormal && calcount == 3) begin
            if (tmpbuf[12:0] >= (1 << 7))
                tmpbuf[6:0] <= {tmpbuf[12:7], 1'b0};    // padding at right
            else
                tmpbuf[6:0] <= tmpbuf[6:0];
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

    reg [51:0] frac;    // 52-bit
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
        else if (!calend && calcount == 5) begin
            if (subnormal)
                expn <= sign_Aexpn - 11'd1022 - sign_idxMsb;
            else
                expn <= sign_Aexpn + sign_Bexpn - 11'd1023 + sign_carry;
        end
        else if (!calend && calcount == 6) begin
            if (subnormal && mprod[105])
                expn <= expn + sign_carry;
        end
        else if (!calend && calcount == 8) begin
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

    always @(posedge CLK) begin
        // no reset
        if (inend && calcount == 0) begin
            // A is NaN
            if (A[62:52] == {11{1'b1}} && A[51:0])
                frac <= A[51:0];
            // B is NaN
            else if (B[62:52] == {11{1'b1}} && B[51:0])
                frac <= B[51:0];
            // A is 0 and B is \infty
            else if (!A[62:0] && B[62:52] == {11{1'b1}} && !B[51:0])
                frac[0] <= 1;
            // B is 0 and A is \infty
            else if (!B[62:0] && A[62:52] == {11{1'b1}} && !A[51:0])
                frac[0] <= 1;
            // not special case
            else
                frac <= 52'd0;
        end
        else if (!calend && calcount == 9) begin
            frac <= mprod[103:52];
        end
    end

    always @(posedge CLK) begin
        if (RESET)
            outcount <= 0;
        else if (outend)
            outcount <= 0;
        else if (calend && !outend)
            outcount <= outcount + 1;
    end

    always @(posedge CLK) begin
        if (RESET)
            outend <= 0;
        else if (outend)
            outend <= 0;
        else if (outcount == 7)
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
                0: DATA_OUT <= frac[7:0];
                1: DATA_OUT <= frac[15:8];
                2: DATA_OUT <= frac[23:16];
                3: DATA_OUT <= frac[31:24];
                4: DATA_OUT <= frac[39:32];
                5: DATA_OUT <= frac[47:40];
                6: DATA_OUT <= {expn[3:0], frac[51:48]};
                7: DATA_OUT <= {sign, expn[10:4]};
            endcase
        end
    end
endmodule