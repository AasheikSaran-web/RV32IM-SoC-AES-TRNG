`timescale 1ns/1ps
module tb_branch;

    reg  [31:0] rs1, rs2;
    reg  [2:0]  funct3;
    wire        taken;

    wire eq   = (rs1 == rs2);
    wire lt_s = $signed(rs1) < $signed(rs2);
    wire lt_u = rs1 < rs2;

    assign taken =
        (funct3 == 3'b000) ?  eq   :
        (funct3 == 3'b001) ? !eq   :
        (funct3 == 3'b100) ?  lt_s :
        (funct3 == 3'b101) ? !lt_s :
        (funct3 == 3'b110) ?  lt_u :
        (funct3 == 3'b111) ? !lt_u :
        1'b0;

    integer pass=0, fail=0;
    task check;
        input got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass=pass+1; end
            else begin $display("  FAIL [%0s] taken=%b exp=%b", label, got, exp); fail=fail+1; end
        end
    endtask

    initial begin
        $dumpfile("tb_branch.vcd");
        $dumpvars(0, tb_branch);

        funct3 = 3'b000;
        rs1=32'd5;         rs2=32'd5;          #1; check(taken, 1, "BEQ_EQUAL");
        rs1=32'd5;         rs2=32'd6;          #1; check(taken, 0, "BEQ_NOT_EQUAL");
        rs1=32'd0;         rs2=32'd0;          #1; check(taken, 1, "BEQ_ZERO_ZERO");
        rs1=32'hFFFF_FFFF; rs2=32'hFFFF_FFFF; #1; check(taken, 1, "BEQ_MAX_MAX");
        rs1=32'hFFFF_FFFF; rs2=32'd0;         #1; check(taken, 0, "BEQ_MAX_ZERO");

        funct3 = 3'b001;
        rs1=32'd5; rs2=32'd5; #1; check(taken, 0, "BNE_EQUAL");
        rs1=32'd5; rs2=32'd6; #1; check(taken, 1, "BNE_DIFFERENT");
        rs1=32'd0; rs2=32'd1; #1; check(taken, 1, "BNE_ZERO_ONE");

        funct3 = 3'b100;
        rs1=32'hFFFF_FFFF; rs2=32'd0; #1; check(taken, 1, "BLT_NEG_LT_ZERO");
        rs1=32'd0;         rs2=32'hFFFF_FFFF; #1; check(taken, 0, "BLT_ZERO_NOT_LT_NEG");
        rs1=32'd1;         rs2=32'd2;          #1; check(taken, 1, "BLT_POS_LT_POS");
        rs1=32'h8000_0000; rs2=32'h7FFF_FFFF; #1; check(taken, 1, "BLT_NEGMIN_LT_POSMAX");
        rs1=32'h7FFF_FFFF; rs2=32'h8000_0000; #1; check(taken, 0, "BLT_POSMAX_NOT_LT_NEGMIN");
        rs1=32'd5;         rs2=32'd5;          #1; check(taken, 0, "BLT_EQUAL_NOTTAKEN");

        funct3 = 3'b101;
        rs1=32'd0;         rs2=32'hFFFF_FFFF; #1; check(taken, 1, "BGE_ZERO_GE_NEG");
        rs1=32'hFFFF_FFFF; rs2=32'd0;          #1; check(taken, 0, "BGE_NEG_NOT_GE_ZERO");
        rs1=32'd5;         rs2=32'd5;          #1; check(taken, 1, "BGE_EQUAL");
        rs1=32'h7FFF_FFFF; rs2=32'h8000_0000; #1; check(taken, 1, "BGE_POSMAX_GE_NEGMIN");

        funct3 = 3'b110;
        rs1=32'd0;         rs2=32'hFFFF_FFFF; #1; check(taken, 1, "BLTU_ZERO_LT_UMAX");
        rs1=32'hFFFF_FFFF; rs2=32'd0;          #1; check(taken, 0, "BLTU_UMAX_NOT_LT_ZERO");
        rs1=32'h7FFF_FFFF; rs2=32'h8000_0000; #1; check(taken, 1, "BLTU_POSMAX_LT_NEGMIN");
        rs1=32'h8000_0000; rs2=32'h7FFF_FFFF; #1; check(taken, 0, "BLTU_NEGMIN_NOT_LT_POSMAX");
        rs1=32'hAAAA;      rs2=32'hAAAA;       #1; check(taken, 0, "BLTU_EQUAL_NOTTAKEN");

        funct3 = 3'b111;
        rs1=32'hFFFF_FFFF; rs2=32'd0;         #1; check(taken, 1, "BGEU_UMAX_GE_ZERO");
        rs1=32'd0;         rs2=32'hFFFF_FFFF; #1; check(taken, 0, "BGEU_ZERO_NOT_GE_UMAX");
        rs1=32'd7;         rs2=32'd7;          #1; check(taken, 1, "BGEU_EQUAL");

        funct3 = 3'b010; rs1=32'd0; rs2=32'd0; #1; check(taken, 0, "INVALID_FUNCT3");
        funct3 = 3'b011; #1; check(taken, 0, "INVALID_FUNCT3_2");

        $display("\n=== BRANCH Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
