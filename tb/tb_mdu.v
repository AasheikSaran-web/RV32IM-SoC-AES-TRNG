`timescale 1ns/1ps
module tb_mdu;

    reg         clk, rst_n;
    reg  [31:0] rs1, rs2;
    reg  [2:0]  funct3;

    reg         start;
    wire [31:0] result;
    wire        done;

    reg  [63:0] mul_result;
    reg  [31:0] div_result, rem_result;
    reg         busy;
    reg  [31:0] out_reg;
    reg         done_reg;
    reg  [2:0]  op_hold;

    assign result = out_reg;
    assign done   = done_reg;

    wire signed [31:0] srs1 = rs1;
    wire signed [31:0] srs2 = rs2;
    wire signed [32:0] urs2_ext = {1'b0, rs2};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0; done_reg <= 0; out_reg <= 0;
        end else begin
            done_reg <= 0;
            if (start && !busy) begin
                busy <= 1;
                op_hold <= funct3;
                case (funct3)
                    3'd0: mul_result <= srs1 * srs2;
                    3'd1: mul_result <= srs1 * srs2;
                    3'd2: mul_result <= srs1 * urs2_ext;
                    3'd3: mul_result <= {32'd0,rs1} * {32'd0,rs2};
                    3'd4: begin
                        if (rs2==0) div_result <= 32'hFFFF_FFFF;
                        else if (rs1==32'h8000_0000 && rs2==32'hFFFF_FFFF) div_result <= 32'h8000_0000;
                        else begin : sdiv_blk
                            reg signed [31:0] sdv;
                            sdv = $signed(rs1) / $signed(rs2);
                            div_result <= sdv;
                        end
                    end
                    3'd5: div_result <= (rs2==0) ? 32'hFFFF_FFFF : rs1 / rs2;
                    3'd6: begin
                        if (rs2==0) rem_result <= rs1;
                        else if (rs1==32'h8000_0000 && rs2==32'hFFFF_FFFF) rem_result <= 32'd0;
                        else begin : srem_blk
                            reg signed [31:0] srm;
                            srm = $signed(rs1) % $signed(rs2);
                            rem_result <= srm;
                        end
                    end
                    3'd7: rem_result <= (rs2==0) ? rs1 : rs1 % rs2;
                endcase
            end else if (busy) begin
                busy <= 0;
                done_reg <= 1;
                case (op_hold)
                    3'd0: out_reg <= mul_result[31:0];
                    3'd1: out_reg <= mul_result[63:32];
                    3'd2: out_reg <= mul_result[63:32];
                    3'd3: out_reg <= mul_result[63:32];
                    3'd4: out_reg <= div_result;
                    3'd5: out_reg <= div_result;
                    3'd6: out_reg <= rem_result;
                    3'd7: out_reg <= rem_result;
                endcase
            end
        end
    end

    always #5 clk = ~clk;

    task run_op;
        input [31:0] a, b;
        input [2:0] op;
        begin
            rs1=a; rs2=b; funct3=op;
            start=1; @(posedge clk); #1; start=0;
            wait(done_reg); @(posedge clk); #1;
        end
    endtask

    integer pass=0, fail=0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s] %08h", label, got); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%08h exp=%08h", label, got, exp); fail=fail+1; end
        end
    endtask

    initial begin
        $dumpfile("tb_mdu.vcd");
        $dumpvars(0, tb_mdu);
        clk=0; rst_n=0; start=0; rs1=0; rs2=0; funct3=0;
        @(posedge clk); rst_n=1;

        run_op(32'd6, 32'd7, 3'd0); check(result, 32'd42, "MUL_6x7");
        run_op(32'hFFFF_FFFF, 32'd2, 3'd0);
        check(result, 32'hFFFF_FFFE, "MUL_NEG1x2_LOW");
        run_op(32'd0, 32'd12345, 3'd0); check(result, 32'd0, "MUL_ZERO");

        run_op(32'h7FFF_FFFF, 32'h7FFF_FFFF, 3'd1);
        check(result, 32'h3FFF_FFFF, "MULH_POSMAX_SQ");
        run_op(32'h8000_0000, 32'h8000_0000, 3'd1);
        check(result, 32'h4000_0000, "MULH_NEGMIN_SQ");

        run_op(32'hFFFF_FFFF, 32'd2, 3'd2);
        check(result, 32'hFFFF_FFFF, "MULHSU_NEG1x2_HI");

        run_op(32'hFFFF_FFFF, 32'hFFFF_FFFF, 3'd3);
        check(result, 32'hFFFF_FFFE, "MULHU_UMAX_SQ_HI");

        run_op(32'd20, 32'd3, 3'd4); check(result, 32'd6, "DIV_20_3");
        run_op(32'hFFFF_FFFF, 32'hFFFF_FFFF, 3'd4); check(result, 32'd1, "DIV_NEG1_NEG1");
        run_op(32'hFFFF_FFE0, 32'd4, 3'd4);
        check(result, 32'hFFFF_FFF8, "DIV_NEG_POS");

        run_op(32'h8000_0000, 32'hFFFF_FFFF, 3'd4);
        check(result, 32'h8000_0000, "DIV_OVERFLOW");

        run_op(32'd5, 32'd0, 3'd4); check(result, 32'hFFFF_FFFF, "DIV_BY_ZERO");

        run_op(32'd100, 32'd7, 3'd5); check(result, 32'd14, "DIVU_100_7");
        run_op(32'hFFFF_FFFF, 32'd2, 3'd5);
        check(result, 32'h7FFF_FFFF, "DIVU_UMAX_2");
        run_op(32'd5, 32'd0, 3'd5); check(result, 32'hFFFF_FFFF, "DIVU_BY_ZERO");

        run_op(32'd20, 32'd3, 3'd6); check(result, 32'd2, "REM_20_3");
        run_op(32'hFFFF_FFE0, 32'd3, 3'd6);
        check(result, 32'hFFFF_FFFE, "REM_NEG32_3");
        run_op(32'd5, 32'd0, 3'd6); check(result, 32'd5, "REM_BY_ZERO");

        run_op(32'd17, 32'd5, 3'd7); check(result, 32'd2, "REMU_17_5");
        run_op(32'd5, 32'd0, 3'd7); check(result, 32'd5, "REMU_BY_ZERO");

        $display("\n=== MDU Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
