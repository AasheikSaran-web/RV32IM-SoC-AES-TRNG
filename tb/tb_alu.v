`timescale 1ns/1ps
module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  op;
    wire [31:0] result;
    wire        zero;

    wire [32:0] add_res = {a[31], a} + {b[31], b};
    wire [32:0] sub_res = {a[31], a} - {b[31], b};

    function [31:0] do_sra;
        input [31:0] val;
        input [4:0]  shamt;
        reg signed [31:0] sv;
        begin sv = val; do_sra = sv >>> shamt; end
    endfunction

    wire signed [31:0] sa = a;
    wire signed [31:0] sb = b;

    assign result =
        (op == 4'b0000) ? a + b :
        (op == 4'b1000) ? a - b :
        (op == 4'b0001) ? a << b[4:0] :
        (op == 4'b0010) ? (sa < sb) ? 32'd1 : 32'd0 :
        (op == 4'b0011) ? (a  < b)  ? 32'd1 : 32'd0 :
        (op == 4'b0100) ? a ^ b :
        (op == 4'b0101) ? a >> b[4:0] :
        (op == 4'b1101) ? do_sra(a, b[4:0]) :
        (op == 4'b0110) ? a | b :
        (op == 4'b0111) ? a & b :
        32'hxxxx_xxxx;

    assign zero = (result == 32'd0);

    integer pass=0, fail=0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%08h exp=%08h", label, got, exp); fail=fail+1; end
        end
    endtask
    task check1;
        input got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%b exp=%b", label, got, exp); fail=fail+1; end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        op=4'b0000;
        a=32'd10; b=32'd5;   #1; check(result, 32'd15,          "ADD_BASIC");
        a=32'hFFFF_FFFF; b=32'd1; #1; check(result, 32'd0,      "ADD_OVERFLOW_WRAP");
        a=32'h7FFF_FFFF; b=32'd1; #1; check(result, 32'h8000_0000, "ADD_POSMAX_TO_NEG");
        a=32'h8000_0000; b=32'h8000_0000; #1; check(result, 32'd0, "ADD_NEG_OVERFLOW");
        check1(zero, 1, "ADD_ZERO_FLAG");

        op=4'b1000;
        a=32'd10; b=32'd5; #1; check(result, 32'd5,             "SUB_BASIC");
        a=32'd0;  b=32'd1; #1; check(result, 32'hFFFF_FFFF,     "SUB_UNDERFLOW");
        a=b;               #1; check(result, 32'd0, "SUB_EQUAL");
        check1(zero, 1, "SUB_ZERO_FLAG");
        a=32'h8000_0000; b=32'd1; #1; check(result, 32'h7FFF_FFFF, "SUB_NEGMIN_TO_POSMAX");

        op=4'b0001;
        a=32'h0000_0001; b=32'd0;  #1; check(result, 32'h0000_0001, "SLL_0");
        a=32'h0000_0001; b=32'd1;  #1; check(result, 32'h0000_0002, "SLL_1");
        a=32'h0000_0001; b=32'd31; #1; check(result, 32'h8000_0000, "SLL_31");
        a=32'h0000_0001; b=32'd32; #1; check(result, 32'h0000_0001, "SLL_MOD32");

        op=4'b0010;
        a=32'd5;          b=32'd10;         #1; check(result, 32'd1, "SLT_TRUE");
        a=32'd10;         b=32'd5;          #1; check(result, 32'd0, "SLT_FALSE");
        a=32'hFFFF_FFFF; b=32'd0;          #1; check(result, 32'd1, "SLT_NEG_LT_ZERO");
        a=32'd0;          b=32'hFFFF_FFFF; #1; check(result, 32'd0, "SLT_ZERO_LT_NEG");
        a=32'h7FFF_FFFF; b=32'h8000_0000; #1; check(result, 32'd0, "SLT_POSMAX_GT_NEGMIN");

        op=4'b0011;
        a=32'd5; b=32'd10; #1; check(result, 32'd1, "SLTU_TRUE");
        a=32'd0; b=32'hFFFF_FFFF; #1; check(result, 32'd1, "SLTU_ZERO_LT_MAX");
        a=32'hFFFF_FFFF; b=32'd0; #1; check(result, 32'd0, "SLTU_MAX_NOT_LT_ZERO");

        op=4'b0100;
        a=32'hAAAA_AAAA; b=32'h5555_5555; #1; check(result, 32'hFFFF_FFFF, "XOR_ALL1");
        a=32'hFFFF_FFFF; b=32'hFFFF_FFFF; #1; check(result, 32'd0,         "XOR_SELF_ZERO");

        op=4'b0101;
        a=32'h8000_0000; b=32'd1;  #1; check(result, 32'h4000_0000, "SRL_NO_SIGN_EXT");
        a=32'hFFFF_FFFF; b=32'd4;  #1; check(result, 32'h0FFF_FFFF, "SRL_4");

        op=4'b1101;
        a=32'h8000_0000; b=32'd1;  #1; check(result, 32'hC000_0000, "SRA_SIGN_EXT");
        a=32'hFFFF_FFFF; b=32'd31; #1; check(result, 32'hFFFF_FFFF, "SRA_ALL_ONES");
        a=32'h7FFF_FFFF; b=32'd1;  #1; check(result, 32'h3FFF_FFFF, "SRA_POS_NO_EXT");

        op=4'b0110;
        a=32'h0F0F_0F0F; b=32'hF0F0_F0F0; #1; check(result, 32'hFFFF_FFFF, "OR_ALL1");
        a=32'd0; b=32'd0; #1; check(result, 32'd0, "OR_ZERO");

        op=4'b0111;
        a=32'hFFFF_FFFF; b=32'h0F0F_0F0F; #1; check(result, 32'h0F0F_0F0F, "AND_MASK");
        a=32'hAAAA_AAAA; b=32'h5555_5555; #1; check(result, 32'd0,          "AND_ZERO");

        $display("\n=== ALU Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
